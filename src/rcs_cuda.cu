#include "rcs_common.hpp"
#include <cuda_runtime.h>

#define CUDA_OK(call) do { const cudaError_t e=(call); if(e!=cudaSuccess) throw std::runtime_error(cudaGetErrorString(e)); } while(0)

struct DeviceProfile { unsigned char matrix, governance; double severity[10]; };
struct DeviceResult { double p_bio, score; unsigned char final_grade, grade_route; };

__global__ void score_kernel(const DeviceProfile* profiles, DeviceResult* results, std::size_t n) {
  const std::size_t i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  const DeviceProfile p = profiles[i];
  const double fw[5] = {30.,15.,10.,20.,25.};
  const double sw[5] = {25.,25.,15.,20.,15.};
  const int offset = p.matrix == 0 ? 0 : 5;
  double penalty = 0.0;
  for (int j=0; j<5; ++j) penalty += p.severity[offset+j] * (p.matrix == 0 ? fw[j] : sw[j]);
  const double score = 100.0 - penalty;
  unsigned char grade = score >= 90. ? 0 : score >= 80. ? 1 : score >= 65. ? 2 : score >= 50. ? 3 : 4;
  const unsigned char route = !p.governance ? 2 : score < 50. ? 1 : 0;
  if (!p.governance) grade = 4;
  results[i] = {penalty, score, grade, route};
}

int main(int argc, char** argv) {
  try {
    const auto args = rcs::parse_arguments(argc, argv);
    const auto host = rcs::read_profiles(args.input);
    std::vector<DeviceProfile> input(host.size());
    for (std::size_t i=0;i<host.size();++i) { input[i].matrix=host[i].matrix; input[i].governance=host[i].governance; for(int j=0;j<10;++j) input[i].severity[j]=host[i].severity[j]; }
    std::vector<DeviceResult> output(host.size());
    DeviceProfile* d_input=nullptr; DeviceResult* d_output=nullptr;
    const auto total_start=std::chrono::steady_clock::now();
    CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_input), input.size()*sizeof(DeviceProfile)));
    CUDA_OK(cudaMalloc(reinterpret_cast<void**>(&d_output), output.size()*sizeof(DeviceResult)));
    CUDA_OK(cudaMemcpy(d_input,input.data(),input.size()*sizeof(DeviceProfile),cudaMemcpyHostToDevice));
    cudaEvent_t begin,end; CUDA_OK(cudaEventCreate(&begin)); CUDA_OK(cudaEventCreate(&end));
    CUDA_OK(cudaEventRecord(begin));
    score_kernel<<<static_cast<unsigned>((host.size()+255)/256),256>>>(d_input,d_output,host.size());
    CUDA_OK(cudaEventRecord(end)); CUDA_OK(cudaEventSynchronize(end)); CUDA_OK(cudaGetLastError());
    float kernel_ms=0; CUDA_OK(cudaEventElapsedTime(&kernel_ms,begin,end));
    CUDA_OK(cudaMemcpy(output.data(),d_output,output.size()*sizeof(DeviceResult),cudaMemcpyDeviceToHost));
    CUDA_OK(cudaFree(d_input)); CUDA_OK(cudaFree(d_output)); CUDA_OK(cudaEventDestroy(begin)); CUDA_OK(cudaEventDestroy(end));
    const double total=std::chrono::duration<double>(std::chrono::steady_clock::now()-total_start).count();
    std::vector<rcs::Result> results(output.size());
    for(std::size_t i=0;i<output.size();++i) results[i]={output[i].p_bio,output[i].score,output[i].final_grade,output[i].grade_route};
    rcs::write_results(args.output,results);
    rcs::print_timing("cpp_cuda",host.size(),0,total,kernel_ms/1000.0);
    return 0;
  } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
