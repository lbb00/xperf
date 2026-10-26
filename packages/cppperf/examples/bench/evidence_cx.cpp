// Evidence microbench for CX001–CX004 → packages/cppperf/evidence/CX*.jsonl
// g++ -std=c++17 -O2 -o evidence_cx evidence_cx.cpp && ./evidence_cx
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

static const int WARM = 3;
static const int ROUNDS = 9;

static double now_ms() {
  using clock = std::chrono::steady_clock;
  return std::chrono::duration<double, std::milli>(clock::now().time_since_epoch()).count();
}

static double median(std::vector<double>& xs) {
  std::sort(xs.begin(), xs.end());
  size_t n = xs.size();
  if (n == 0) return 0;
  if (n % 2) return xs[n / 2];
  return 0.5 * (xs[n / 2 - 1] + xs[n / 2]);
}

template <typename F>
static double time_many(F fn) {
  for (int i = 0; i < WARM; ++i) fn();
  std::vector<double> samples(ROUNDS);
  volatile size_t sink = 0;
  for (int r = 0; r < ROUNDS; ++r) {
    double t0 = now_ms();
    sink += fn();
    samples[r] = now_ms() - t0;
  }
  (void)sink;
  return median(samples);
}

static int env_int(const char* k, int def) {
  const char* v = std::getenv(k);
  if (!v || !*v) return def;
  return std::atoi(v);
}

static std::string iso_ts() {
  time_t t = time(nullptr);
  struct tm tm{};
  gmtime_r(&t, &tm);
  char buf[32];
  strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%SZ", &tm);
  return buf;
}

static std::string gxx_ver() {
  FILE* p = popen("g++ --version 2>/dev/null | head -1", "r");
  if (!p) return "g++";
  char buf[256];
  if (!fgets(buf, sizeof buf, p)) {
    pclose(p);
    return "g++";
  }
  pclose(p);
  std::string s(buf);
  while (!s.empty() && (s.back() == '\n' || s.back() == '\r')) s.pop_back();
  return s;
}

struct Line {
  std::string rule, case_name, role;
  double med;
  int ops;
  double ratio;
};

int main() {
  const char* out_env = std::getenv("EVIDENCE_DIR");
  std::string out_dir = out_env ? out_env : "packages/cppperf/evidence";
  // Prefer relative to cwd when run from examples/bench
  if (!out_env) {
    out_dir = "../../evidence";
  }
  std::string ver = gxx_ver();
  std::string opt = "O2";
  std::string ts = iso_ts();
  std::vector<Line> all;

  auto emit = [&](const char* rule, const char* cse, const char* role, double med, int ops, double ratio) {
    all.push_back({rule, cse, role, med, ops, ratio});
    fprintf(stderr, "  %s %s %s median=%.3f ms ops=%d ratio=%.3f\n", rule, role, cse, med, ops, ratio);
  };

  // CX001 push_back without reserve vs reserve
  int n1 = env_int("CX001_N", 500000);
  fprintf(stderr, "CX001 push_back n=%d\n", n1);
  double m1a = time_many([&]() -> size_t {
    std::vector<int> v;
    v.reserve(static_cast<size_t>(n1));
    for (int i = 0; i < n1; ++i) v.push_back(i);
    return v.size();
  });
  double m1b = time_many([&]() -> size_t {
    std::vector<int> v;
    for (int i = 0; i < n1; ++i) v.push_back(i);
    return v.size();
  });
  emit("CX001", "reserve_then_push", "after", m1a, n1, 1.0);
  emit("CX001", "push_no_reserve", "before", m1b, n1, m1b / std::max(m1a, 1e-9));

  int n1s = env_int("CX001_N_SMALL", 100);
  double m1sa = time_many([&]() -> size_t {
    std::vector<int> v;
    v.reserve(static_cast<size_t>(n1s));
    for (int i = 0; i < n1s; ++i) v.push_back(i);
    return v.size();
  });
  double m1sb = time_many([&]() -> size_t {
    std::vector<int> v;
    for (int i = 0; i < n1s; ++i) v.push_back(i);
    return v.size();
  });
  emit("CX001", "small_reserve", "after", m1sa, n1s, 1.0);
  emit("CX001", "small_push_no_reserve", "before", m1sb, n1s, m1sb / std::max(m1sa, 1e-9));

  // cx-string-append-unreserved string += vs reserve+append
  int n2 = env_int("CX002_N", 200000);
  std::vector<const char*> parts(static_cast<size_t>(n2), "x");
  fprintf(stderr, "cx-string-append-unreserved string-plus n=%d\n", n2);
  double m2a = time_many([&]() -> size_t {
    std::string s;
    s.reserve(static_cast<size_t>(n2));
    for (int i = 0; i < n2; ++i) s += parts[static_cast<size_t>(i)];
    return s.size();
  });
  double m2b = time_many([&]() -> size_t {
    std::string s;
    for (int i = 0; i < n2; ++i) s += parts[static_cast<size_t>(i)];
    return s.size();
  });
  emit("cx-string-append-unreserved", "string_reserve_plus", "after", m2a, n2, 1.0);
  emit("cx-string-append-unreserved", "string_plus_grow", "before", m2b, n2, m2b / std::max(m2a, 1e-9));

  // CX003 iostream in loop vs buffered string then one write (to /dev/null)
  int n3 = env_int("CX003_N", 50000);
  fprintf(stderr, "CX003 iostream n=%d\n", n3);
  double m3a = time_many([&]() -> size_t {
    std::ostringstream oss;
    for (int i = 0; i < n3; ++i) oss << i << '\n';
    std::ofstream null("/dev/null");
    null << oss.str();
    return static_cast<size_t>(n3);
  });
  double m3b = time_many([&]() -> size_t {
    std::ofstream null("/dev/null");
    for (int i = 0; i < n3; ++i) null << i << '\n';
    return static_cast<size_t>(n3);
  });
  emit("CX003", "ostringstream_once", "after", m3a, n3, 1.0);
  emit("CX003", "iostream_in_loop", "before", m3b, n3, m3b / std::max(m3a, 1e-9));

  // CX004 .at() vs operator[]
  int n4 = env_int("CX004_N", 5000000);
  std::vector<int> v(static_cast<size_t>(n4));
  for (int i = 0; i < n4; ++i) v[static_cast<size_t>(i)] = i;
  fprintf(stderr, "CX004 at-vs-index n=%d\n", n4);
  double m4a = time_many([&]() -> size_t {
    long long total = 0;
    for (size_t i = 0; i < v.size(); ++i) total += v[i];
    return static_cast<size_t>(total & 0xffff);
  });
  double m4b = time_many([&]() -> size_t {
    long long total = 0;
    for (size_t i = 0; i < v.size(); ++i) total += v.at(i);
    return static_cast<size_t>(total & 0xffff);
  });
  emit("CX004", "operator_index", "after", m4a, n4, 1.0);
  emit("CX004", "vector_at", "before", m4b, n4, m4b / std::max(m4a, 1e-9));

  int n4s = env_int("CX004_N_SMALL", 1000);
  std::vector<int> vs(static_cast<size_t>(n4s));
  for (int i = 0; i < n4s; ++i) vs[static_cast<size_t>(i)] = i;
  // amplify small
  int reps = env_int("CX004_SMALL_REPS", 5000);
  double m4sa = time_many([&]() -> size_t {
    long long total = 0;
    for (int r = 0; r < reps; ++r)
      for (size_t i = 0; i < vs.size(); ++i) total += vs[i];
    return static_cast<size_t>(total & 0xffff);
  });
  double m4sb = time_many([&]() -> size_t {
    long long total = 0;
    for (int r = 0; r < reps; ++r)
      for (size_t i = 0; i < vs.size(); ++i) total += vs.at(i);
    return static_cast<size_t>(total & 0xffff);
  });
  emit("CX004", "small_operator_index", "after", m4sa, n4s, 1.0);
  emit("CX004", "small_vector_at", "before", m4sb, n4s, m4sb / std::max(m4sa, 1e-9));

  // write jsonl per rule
  for (const char* rule : {"CX001", "cx-string-append-unreserved", "CX003", "CX004"}) {
    std::string path = out_dir + "/" + rule + ".jsonl";
    FILE* f = fopen(path.c_str(), "w");
    if (!f) {
      fprintf(stderr, "cannot write %s\n", path.c_str());
      return 1;
    }
    for (const auto& L : all) {
      if (L.rule != rule) continue;
      fprintf(f,
              "{\"rule\":\"%s\",\"case\":\"%s\",\"role\":\"%s\",\"gxx\":\"%s\",\"opt\":\"%s\","
              "\"median_ms\":%.6f,\"ops\":%d,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
              L.rule.c_str(), L.case_name.c_str(), L.role.c_str(), ver.c_str(), opt.c_str(), L.med, L.ops, L.ratio,
              ts.c_str());
      printf("{\"rule\":\"%s\",\"case\":\"%s\",\"role\":\"%s\",\"gxx\":\"%s\",\"opt\":\"%s\","
             "\"median_ms\":%.6f,\"ops\":%d,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
             L.rule.c_str(), L.case_name.c_str(), L.role.c_str(), ver.c_str(), opt.c_str(), L.med, L.ops, L.ratio,
             ts.c_str());
    }
    fclose(f);
    fprintf(stderr, "wrote %s\n", path.c_str());
  }
  return 0;
}
