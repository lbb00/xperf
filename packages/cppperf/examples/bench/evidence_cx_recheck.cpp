#include <chrono>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace {
constexpr int kWarm = 3;
constexpr int kRounds = 9;

double median(double* xs, int n) {
  for (int i = 1; i < n; ++i) {
    double v = xs[i];
    int j = i;
    while (j > 0 && xs[j - 1] > v) {
      xs[j] = xs[j - 1];
      --j;
    }
    xs[j] = v;
  }
  return xs[n / 2];
}

template <typename Fn>
double time_many(const char* name, Fn fn) {
  for (int i = 0; i < kWarm; ++i) fn();
  double samples[kRounds];
  std::uint64_t sink = 0;
  for (int i = 0; i < kRounds; ++i) {
    auto t0 = std::chrono::steady_clock::now();
    sink += static_cast<std::uint64_t>(fn());
    auto t1 = std::chrono::steady_clock::now();
    samples[i] = std::chrono::duration<double, std::milli>(t1 - t0).count();
  }
  if (sink == 0xffffffffffffffffull) return -1;
  double med = median(samples, kRounds);
  std::printf("%s median_ms=%.6f samples", name, med);
  for (int i = 0; i < kRounds; ++i) std::printf(" %.3f", samples[i]);
  std::printf("\n");
  return med;
}

int vec_reserve() {
  std::vector<int> v;
  v.reserve(500000);
  for (int i = 0; i < 500000; ++i) v.push_back(i);
  volatile int sink = v.back();
  return sink;
}

int vec_grow() {
  std::vector<int> v;
  for (int i = 0; i < 500000; ++i) v.push_back(i);
  volatile int sink = v.back();
  return sink;
}

int str_reserve() {
  std::string s;
  s.reserve(200000);
  for (int i = 0; i < 200000; ++i) s.push_back('x');
  volatile int sink = static_cast<int>(s.size());
  return sink;
}

int str_grow() {
  std::string s;
  for (int i = 0; i < 200000; ++i) s.push_back('x');
  volatile int sink = static_cast<int>(s.size());
  return sink;
}
}  // namespace

int main() {
  double a = time_many("reserve_then_push", vec_reserve);
  double b = time_many("push_no_reserve", vec_grow);
  std::printf("ratio_push_no_reserve=%.6f\n", b / a);
  double c = time_many("string_reserve", str_reserve);
  double d = time_many("string_grow", str_grow);
  std::printf("ratio_string_grow=%.6f\n", d / c);
  std::printf("DONE_CX_RECHECK\n");
  return 0;
}
