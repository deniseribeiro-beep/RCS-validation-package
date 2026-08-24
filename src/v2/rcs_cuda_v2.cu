#include "rcs_benchmark_common.hpp"
#include <cuda_runtime.h>

#define CUDA_OK(call) do { const cudaError_t e=(call); if(e!=cudaSuccess) throw std::runtime_error(cudaGetErrorString(e)); } while(0)

struct DeviceProfile { unsigned char matrix, governance; double severity[10]; };
struct DeviceResult { double p_bio, score; unsigned char final_grade, grade_route; };

__global__ void score_kernel_v2(const DeviceProfile* profiles, DeviceResult* results, std::size_t n) {
  const std::size_t i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  const DeviceProfile p = profiles[i];
  const double fw[5] = {30., 15., 10., 20., 25.};
  const double sw[5] = {25., 25., 15., 20., 15.};
  const int offset = p.matrix == 0 ? 0 : 5;
  double penalty = 0.0;
  for (int j = 0; j < 5; ++j) penalty += p.severity[offset + j] * (p.matrix == 0 ? fw[j] : sw[j]);
  const double score = 100.0 - penalty;
  unsigned char grade = score >= 90. ? 0 : score >= 80. ? 1 : score >= 65. ? 2 : score >= 50. ? 3 : 4;
  const unsigned char route = !p.governance ? 2 : score < 50. ? 1 : 0;
  if (!p.governance) grade = 4;
  results[i] = {penalty, score, grade, route};
}

static double cuda_event_seconds(const std::function<void()>& operation) {
  cudaEvent_t start, stop;
  CUDA_OK(cudaEventCreate(&start)); CUDA_OK(cudaEventCreate(&stop));
  CUDA_OK(cudaEventRecord(start)); operation(); CUDA_OK(cudaEventRecord(stop));
  CUDA_OK(cudaEventSynchronize(stop)); CUDA_OK(cudaGetLastError());
  float milliseconds = 0.0f;
  CUDA_OK(cudaEventElapsedTime(&milliseconds, start, stop));
  CUDA_OK(cudaEventDestroy(start)); CUDA_OK(cudaEventDestroy(stop));
  return static_cast<double>(milliseconds) / 1000.0;
}

int main(int argc, char** argv) {
  DeviceProfile* d_input = nullptr;
  DeviceResult* d_output = nullptr;
  try {
    const auto args = rcs_v2::parse_arguments(argc, argv);
    std::vector<rcs::Profile> host;
    const double read_seconds = rcs_v2::elapsed([&]() { host = rcs::read_profiles(args.input); });

    std::vector<DeviceProfile> input;
    std::vector<DeviceResult> output;
    const double host_prepare_seconds = rcs_v2::elapsed([&]() {
      input.resize(host.size()); output.resize(host.size());
      for (std::size_t i = 0; i < host.size(); ++i) {
        input[i].matrix = host[i].matrix; input[i].governance = host[i].governance;
        for (int j = 0; j < 10; ++j) input[i].severity[j] = host[i].severity[j];
      }
    });
    const double device_setup_seconds = rcs_v2::elapsed([&]() {
      CUDA_OK(cudaFree(nullptr));
      CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_input), input.size() * sizeof(DeviceProfile)));
      CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_output), output.size() * sizeof(DeviceResult)));
    });
    const double h2d_seconds = rcs_v2::elapsed([&]() {
      CUDA_OK(cudaMemcpy(d_input, input.data(), input.size() * sizeof(DeviceProfile), cudaMemcpyHostToDevice));
    });
    const auto launch = [&]() {
      score_kernel_v2<<<static_cast<unsigned>((host.size() + 255) / 256), 256>>>(d_input, d_output, host.size());
    };

    int loops = 1;
    double kernel_seconds = NAN;
    if (args.mode == "compute") {
      for (int i = 0; i < args.warmups; ++i) launch();
      CUDA_OK(cudaDeviceSynchronize()); CUDA_OK(cudaGetLastError());
      const double pilot = cuda_event_seconds(launch);
      loops = pilot > 0.0 ? std::max(1, std::min(args.max_loops,
        static_cast<int>(std::ceil(args.min_seconds / pilot)))) : args.max_loops;
      kernel_seconds = cuda_event_seconds([&]() { for (int i = 0; i < loops; ++i) launch(); }) / loops;
    } else {
      kernel_seconds = cuda_event_seconds(launch);
    }

    const double d2h_seconds = rcs_v2::elapsed([&]() {
      CUDA_OK(cudaMemcpy(output.data(), d_output, output.size() * sizeof(DeviceResult), cudaMemcpyDeviceToHost));
    });
    const double device_teardown_seconds = rcs_v2::elapsed([&]() {
      CUDA_OK(cudaFree(d_input)); d_input = nullptr;
      CUDA_OK(cudaFree(d_output)); d_output = nullptr;
    });

    std::vector<rcs::Result> results;
    const double host_finalize_seconds = rcs_v2::elapsed([&]() {
      results.resize(output.size());
      for (std::size_t i = 0; i < output.size(); ++i)
        results[i] = {output[i].p_bio, output[i].score, output[i].final_grade, output[i].grade_route};
    });
    const double disk_write_seconds = rcs_v2::elapsed([&]() { rcs::write_results(args.output, results); });

    if (args.mode == "e2e") {
      const double initialization = host_prepare_seconds + device_setup_seconds + h2d_seconds;
      const double writing = d2h_seconds + device_teardown_seconds + host_finalize_seconds + disk_write_seconds;
      rcs_v2::print_phases(read_seconds, initialization, kernel_seconds, writing);
      std::cout << std::setprecision(12) << "V2CUDA," << host_prepare_seconds << ','
                << device_setup_seconds << ',' << h2d_seconds << ',' << kernel_seconds << ','
                << d2h_seconds << ',' << device_teardown_seconds << ',' << host_finalize_seconds << ','
                << disk_write_seconds << '\n';
    }
    rcs_v2::print_result(args, host.size(), loops, args.mode == "compute" ? kernel_seconds : NAN);
    return 0;
  } catch (const std::exception& e) {
    if (d_input) cudaFree(d_input);
    if (d_output) cudaFree(d_output);
    std::cerr << e.what() << '\n'; return 1;
  }
}
