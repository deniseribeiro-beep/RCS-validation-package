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

int main(int argc, char** argv) {
  try {
    const auto args = rcs_v2::parse_arguments(argc, argv);
    const auto host = rcs::read_profiles(args.input);
    std::vector<DeviceProfile> input(host.size());
    for (std::size_t i = 0; i < host.size(); ++i) {
      input[i].matrix = host[i].matrix; input[i].governance = host[i].governance;
      for (int j = 0; j < 10; ++j) input[i].severity[j] = host[i].severity[j];
    }
    std::vector<DeviceResult> output(host.size());
    DeviceProfile* d_input = nullptr; DeviceResult* d_output = nullptr;
    CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_input), input.size() * sizeof(DeviceProfile)));
    CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_output), output.size() * sizeof(DeviceResult)));
    CUDA_OK(cudaMemcpy(d_input, input.data(), input.size() * sizeof(DeviceProfile), cudaMemcpyHostToDevice));
    const auto launch = [&]() {
      score_kernel_v2<<<static_cast<unsigned>((host.size() + 255) / 256), 256>>>(d_input, d_output, host.size());
    };
    int loops = 1;
    double seconds = NAN;
    if (args.mode == "compute") {
      for (int i = 0; i < args.warmups; ++i) launch();
      CUDA_OK(cudaDeviceSynchronize());
      cudaEvent_t pilot_start, pilot_stop;
      CUDA_OK(cudaEventCreate(&pilot_start)); CUDA_OK(cudaEventCreate(&pilot_stop));
      CUDA_OK(cudaEventRecord(pilot_start)); launch(); CUDA_OK(cudaEventRecord(pilot_stop)); CUDA_OK(cudaEventSynchronize(pilot_stop));
      float pilot_ms = 0; CUDA_OK(cudaEventElapsedTime(&pilot_ms, pilot_start, pilot_stop));
      loops = pilot_ms > 0.0f
        ? std::max(1, std::min(args.max_loops, static_cast<int>(std::ceil(args.min_seconds / (pilot_ms / 1000.0)))))
        : args.max_loops;
      cudaEvent_t start, stop; CUDA_OK(cudaEventCreate(&start)); CUDA_OK(cudaEventCreate(&stop));
      CUDA_OK(cudaEventRecord(start));
      for (int i = 0; i < loops; ++i) launch();
      CUDA_OK(cudaEventRecord(stop)); CUDA_OK(cudaEventSynchronize(stop)); CUDA_OK(cudaGetLastError());
      float measured_ms = 0; CUDA_OK(cudaEventElapsedTime(&measured_ms, start, stop));
      seconds = measured_ms / 1000.0 / loops;
      CUDA_OK(cudaEventDestroy(start)); CUDA_OK(cudaEventDestroy(stop));
      CUDA_OK(cudaEventDestroy(pilot_start)); CUDA_OK(cudaEventDestroy(pilot_stop));
    } else {
      launch(); CUDA_OK(cudaDeviceSynchronize()); CUDA_OK(cudaGetLastError());
    }
    CUDA_OK(cudaMemcpy(output.data(), d_output, output.size() * sizeof(DeviceResult), cudaMemcpyDeviceToHost));
    CUDA_OK(cudaFree(d_input)); CUDA_OK(cudaFree(d_output));
    std::vector<rcs::Result> results(output.size());
    for (std::size_t i = 0; i < output.size(); ++i)
      results[i] = {output[i].p_bio, output[i].score, output[i].final_grade, output[i].grade_route};
    rcs::write_results(args.output, results);
    rcs_v2::print_result(args, host.size(), loops, seconds);
    return 0;
  } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
