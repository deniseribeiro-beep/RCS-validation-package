#include "rcs_benchmark_common.hpp"
#include <omp.h>

int main(int argc, char** argv) {
  try {
    const auto args = rcs_v2::parse_arguments(argc, argv);
    std::vector<rcs::Profile> profiles;
    const double read_seconds = rcs_v2::elapsed([&]() { profiles = rcs::read_profiles(args.input); });
    const auto init_start = std::chrono::steady_clock::now();
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
      const double init_seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - init_start).count();
      const double compute_seconds = rcs_v2::elapsed(operation);
      const double write_seconds = rcs_v2::elapsed([&]() { rcs::write_results(args.output, results); });
      rcs_v2::print_phases(read_seconds, init_seconds, compute_seconds, write_seconds);
      rcs_v2::print_result(args, profiles.size(), 1, NAN);
      return 0;
    }
    for (int i = 0; i < args.warmups; ++i) operation();
    const auto measurement = rcs_v2::measure_calibrated(operation, args.min_seconds, args.max_loops);
    rcs::write_results(args.output, results);
    rcs_v2::print_result(args, profiles.size(), measurement.loops,
                         measurement.seconds_per_call(), measurement.block_seconds,
                         measurement.floor_passed, measurement.attempts);
    return 0;
  } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
