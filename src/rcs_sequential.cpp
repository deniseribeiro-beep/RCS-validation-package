#include "rcs_common.hpp"

int main(int argc, char** argv) {
  try {
    const auto args = rcs::parse_arguments(argc, argv);
    const auto profiles = rcs::read_profiles(args.input);
    std::vector<rcs::Result> results(profiles.size());
    const auto start = std::chrono::steady_clock::now();
    for (std::size_t i = 0; i < profiles.size(); ++i) results[i] = rcs::score_one(profiles[i]);
    const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    rcs::write_results(args.output, results);
    rcs::print_timing("cpp_sequential", profiles.size(), 1, elapsed);
    return 0;
  } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
