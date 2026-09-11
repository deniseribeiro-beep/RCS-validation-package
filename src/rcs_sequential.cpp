#include "rcs_benchmark_common.hpp"

int main(int argc, char** argv) {
  try {
    const auto args = rcs_benchmark::parse_arguments(argc, argv);
    std::vector<rcs::Profile> profiles;
    const double read_seconds = rcs_benchmark::elapsed([&]() { profiles = rcs::read_profiles(args.input); });
    const auto init_start = std::chrono::steady_clock::now();
    std::vector<rcs::Result> results(profiles.size());
    const auto operation = [&]() {
      for (std::size_t i = 0; i < profiles.size(); ++i) results[i] = rcs::score_one(profiles[i]);
      std::atomic_signal_fence(std::memory_order_seq_cst);
    };
    if (args.mode == "e2e") {
      const double init_seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - init_start).count();
      const double compute_seconds = rcs_benchmark::elapsed(operation);
      const double write_seconds = rcs_benchmark::elapsed([&]() { rcs::write_results(args.output, results); });
      rcs_benchmark::print_phases(read_seconds, init_seconds, compute_seconds, write_seconds);
      rcs_benchmark::print_result(args, profiles.size(), 1, NAN);
      return 0;
    }
    for (int i = 0; i < args.warmups; ++i) operation();
    const auto measurement = rcs_benchmark::measure_calibrated(operation, args.min_seconds, args.max_loops);
    rcs::write_results(args.output, results);
    rcs_benchmark::print_result(args, profiles.size(), measurement.loops,
                                measurement.seconds_per_call(), measurement.block_seconds,
                                measurement.floor_passed, measurement.attempts);
    return 0;
  } catch (const std::exception& e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
