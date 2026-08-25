#ifndef RCS_BENCHMARK_V2_COMMON_HPP
#define RCS_BENCHMARK_V2_COMMON_HPP

#include "../rcs_common.hpp"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <functional>

namespace rcs_v2 {

struct Arguments {
  std::string input, output, implementation, mode;
  int threads = 1;
  int warmups = 3;
  int max_loops = 1000000;
  double min_seconds = 0.25;
};

inline Arguments parse_arguments(int argc, char** argv) {
  Arguments args;
  for (int i = 1; i < argc; ++i) {
    const std::string key = argv[i];
    if (i + 1 >= argc) throw std::runtime_error("Missing value after " + key);
    const std::string value = argv[++i];
    if (key == "--input") args.input = value;
    else if (key == "--output") args.output = value;
    else if (key == "--implementation") args.implementation = value;
    else if (key == "--mode") args.mode = value;
    else if (key == "--threads" || key == "--workers") args.threads = std::stoi(value);
    else if (key == "--warmups") args.warmups = std::stoi(value);
    else if (key == "--min-sec") args.min_seconds = std::stod(value);
    else if (key == "--max-loops") args.max_loops = std::stoi(value);
    else throw std::runtime_error("Unknown argument: " + key);
  }
  if (args.input.empty() || args.output.empty() || args.implementation.empty() ||
      (args.mode != "compute" && args.mode != "e2e"))
    throw std::runtime_error("Required: --input --output --implementation --mode compute|e2e");
  if (args.threads < 1 || args.warmups < 0 || args.max_loops < 1 || args.min_seconds <= 0)
    throw std::runtime_error("Invalid benchmark parameters");
  return args;
}

inline double elapsed(const std::function<void()>& operation) {
  const auto start = std::chrono::steady_clock::now();
  operation();
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
}

inline int calibrate(const std::function<void()>& operation, double minimum, int maximum) {
  int loops = 1;
  while (true) {
    const double observed = elapsed([&]() {
      for (int i = 0; i < loops; ++i) operation();
    });
    if (std::isfinite(observed) && observed >= minimum) return loops;
    if (loops >= maximum) return maximum;

    long long estimate = static_cast<long long>(loops) * 2LL;
    if (std::isfinite(observed) && observed > 0.0) {
      estimate = static_cast<long long>(std::ceil(1.10 * loops * minimum / observed));
    }
    const long long doubled = static_cast<long long>(loops) * 2LL;
    const long long next = std::max({static_cast<long long>(loops) + 1LL, doubled, estimate});
    loops = static_cast<int>(std::min(static_cast<long long>(maximum), next));
  }
}

inline void print_result(const Arguments& args, std::size_t n, int loops, double seconds) {
  std::cout << std::setprecision(12) << "V2RESULT," << args.implementation << ',' << n << ','
            << args.threads << ',' << loops << ',';
  if (std::isfinite(seconds)) std::cout << seconds;
  else std::cout << "NA";
  std::cout << '\n';
}

inline void print_phases(double read_seconds, double init_seconds, double compute_seconds,
                         double write_seconds) {
  std::cout << std::setprecision(12) << "V2PHASES," << read_seconds << ',' << init_seconds << ','
            << compute_seconds << ',' << write_seconds << ','
            << (read_seconds + init_seconds + compute_seconds + write_seconds) << '\n';
}

}  // namespace rcs_v2
#endif
