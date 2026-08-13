#ifndef RCS_COMMON_HPP
#define RCS_COMMON_HPP

#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace rcs {

constexpr std::array<double, 5> fluid_weights{30.0, 15.0, 10.0, 20.0, 25.0};
constexpr std::array<double, 5> solid_weights{25.0, 25.0, 15.0, 20.0, 15.0};

struct Profile {
  std::uint8_t matrix;       // 0 = fluid, 1 = solid
  std::uint8_t governance;   // 0 = failed, 1 = admissible
  std::array<double, 10> severity;
};

struct Result {
  double p_bio;
  double score;
  std::uint8_t final_grade;  // 0=A, 1=B, 2=C, 3=D, 4=E
  std::uint8_t grade_route;  // 0=score, 1=critical burden, 2=governance failure
};

inline Result score_one(const Profile& p) {
  const auto& weights = p.matrix == 0 ? fluid_weights : solid_weights;
  const std::size_t offset = p.matrix == 0 ? 0 : 5;
  double penalty = 0.0;
  bool valid = p.matrix <= 1;
  for (std::size_t j = 0; j < 5; ++j) {
    const double value = p.severity[offset + j];
    valid = valid && value >= 0.0 && value <= 1.0;
    penalty += value * weights[j];
  }
  if (!valid) throw std::runtime_error("Invalid matrix or severity outside [0,1]");
  const double score = 100.0 - penalty;
  std::uint8_t grade = score >= 90.0 ? 0 : score >= 80.0 ? 1 : score >= 65.0 ? 2 : score >= 50.0 ? 3 : 4;
  const std::uint8_t route = !p.governance ? 2 : score < 50.0 ? 1 : 0;
  if (!p.governance) grade = 4;
  return {penalty, score, grade, route};
}

inline std::vector<Profile> read_profiles(const std::string& path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) throw std::runtime_error("Cannot open input: " + path);
  char magic[8]{};
  double n_value = 0;
  in.read(magic, 8);
  in.read(reinterpret_cast<char*>(&n_value), sizeof(n_value));
  if (std::string(magic, 8) != std::string("RCSBIN1\0", 8)) throw std::runtime_error("Invalid RCS binary header");
  if (n_value < 0 || n_value > static_cast<double>(SIZE_MAX)) throw std::runtime_error("Invalid record count");
  const std::uint64_t n = static_cast<std::uint64_t>(n_value);
  std::vector<Profile> profiles(static_cast<std::size_t>(n));
  for (auto& p : profiles) in.read(reinterpret_cast<char*>(&p.matrix), 1);
  for (auto& p : profiles) in.read(reinterpret_cast<char*>(&p.governance), 1);
  for (std::size_t j = 0; j < 10; ++j)
    for (auto& p : profiles) in.read(reinterpret_cast<char*>(&p.severity[j]), sizeof(double));
  if (!in) throw std::runtime_error("Truncated RCS binary input");
  return profiles;
}

inline void write_results(const std::string& path, const std::vector<Result>& results) {
  std::ofstream out(path, std::ios::binary);
  if (!out) throw std::runtime_error("Cannot open output: " + path);
  out.write("RCSOUT1\0", 8);
  const double n = static_cast<double>(results.size());
  out.write(reinterpret_cast<const char*>(&n), sizeof(n));
  for (const auto& r : results) out.write(reinterpret_cast<const char*>(&r.p_bio), sizeof(double));
  for (const auto& r : results) out.write(reinterpret_cast<const char*>(&r.score), sizeof(double));
  for (const auto& r : results) out.write(reinterpret_cast<const char*>(&r.final_grade), 1);
  for (const auto& r : results) out.write(reinterpret_cast<const char*>(&r.grade_route), 1);
}

struct Arguments { std::string input, output; int threads = 1; };

inline Arguments parse_arguments(int argc, char** argv) {
  Arguments args;
  for (int i = 1; i < argc; ++i) {
    const std::string key = argv[i];
    if ((key == "--input" || key == "--output" || key == "--threads") && i + 1 >= argc)
      throw std::runtime_error("Missing value after " + key);
    if (key == "--input") args.input = argv[++i];
    else if (key == "--output") args.output = argv[++i];
    else if (key == "--threads") args.threads = std::stoi(argv[++i]);
    else throw std::runtime_error("Unknown argument: " + key);
  }
  if (args.input.empty() || args.output.empty()) throw std::runtime_error("Usage: --input FILE --output FILE [--threads N]");
  return args;
}

inline void print_timing(const char* implementation, std::size_t n, int threads, double total, double kernel = -1.0) {
  std::cout << std::setprecision(12) << implementation << ',' << n << ',' << threads << ',' << total << ',';
  if (kernel >= 0.0) std::cout << kernel;
  std::cout << '\n';
}

}  // namespace rcs
#endif
