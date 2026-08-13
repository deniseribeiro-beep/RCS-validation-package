#include "rcs_common.hpp"
#include <omp.h>

int main(int argc, char** argv) {
  try {
    const auto args = rcs::parse_arguments(argc, argv);
    const auto profiles = rcs::read_profiles(args.input);
    std::vector<rcs::Result> results(profiles.size());
    omp_set_dynamic(0);
    omp_set_num_threads(args.threads);
    const auto start = std::chrono::steady_clock::now();
#pragma omp parallel for schedule(static)
    for (std::int64_t i = 0; i < static_cast<std::int64_t>(profiles.size()); ++i)
      results[static_cast<std::size_t>(i)] = rcs::score_one(profiles[static_cast<std::size_t>(i)]);
    const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    rcs::write_results(args.output, results);
    rcs::print_timing("cpp_openmp", profiles.size(), args.threads, elapsed);
    return 0;
  } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
