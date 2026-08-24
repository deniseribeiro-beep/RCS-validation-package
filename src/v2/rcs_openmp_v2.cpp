#include "rcs_benchmark_common.hpp"
#include <omp.h>

int main(int argc, char** argv) {
  try {
    const auto args = rcs_v2::parse_arguments(argc, argv);
    const auto profiles = rcs::read_profiles(args.input);
    std::vector<rcs::Result> results(profiles.size());
    omp_set_dynamic(0);
    omp_set_num_threads(args.threads);
    const auto operation = [&]() {
#pragma omp parallel for schedule(static)
      for (std::int64_t i = 0; i < static_cast<std::int64_t>(profiles.size()); ++i)
        results[static_cast<std::size_t>(i)] = rcs::score_one(profiles[static_cast<std::size_t>(i)]);
      std::atomic_signal_fence(std::memory_order_seq_cst);
    };
    if (args.mode == "e2e") {
      operation();
      rcs::write_results(args.output, results);
      rcs_v2::print_result(args, profiles.size(), 1, NAN);
      return 0;
    }
    for (int i = 0; i < args.warmups; ++i) operation();
    const int loops = rcs_v2::calibrate(operation, args.min_seconds, args.max_loops);
    const double seconds = rcs_v2::elapsed([&]() { for (int i = 0; i < loops; ++i) operation(); }) / loops;
    rcs::write_results(args.output, results);
    rcs_v2::print_result(args, profiles.size(), loops, seconds);
    return 0;
  } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}

