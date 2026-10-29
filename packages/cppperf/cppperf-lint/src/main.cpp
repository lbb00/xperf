#include "cppperf_lint.hpp"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <map>
#include <string>
#include <vector>

enum Sev { Off = 0, Hint = 1, Error = 2 };

static Sev parse_sev(const std::string& s) {
  if (s == "error") return Error;
  if (s == "hint") return Hint;
  if (s == "off") return Off;
  return static_cast<Sev>(-1);
}

static const char* sev_name(Sev s) {
  switch (s) {
    case Error: return "error";
    case Hint: return "hint";
    default: return "off";
  }
}

static void usage(int code) {
  std::cerr << "Usage: cppperf-lint PATH... [options]\n"
               "  --format text|json\n"
               "  --severity RULE=error|hint|off\n"
               "  --scope all|loop   (default: all)\n"
               "  --strict-hints\n"
               "  --no-fail\n";
  std::exit(code);
}

static bool apply_sev(std::map<std::string, Sev>& rs, const std::string& spec) {
  auto eq = spec.find('=');
  if (eq == std::string::npos) return false;
  auto rule = spec.substr(0, eq);
  auto sev = parse_sev(spec.substr(eq + 1));
  if (rs.count(rule) == 0 || static_cast<int>(sev) < 0) return false;
  rs[rule] = sev;
  return true;
}

static std::string join_with_sep(const std::vector<std::string>& parts, char sep) {
  if (parts.empty()) return {};
  size_t n = parts.size() - 1;
  for (const auto& p : parts) n += p.size();
  std::string out(n, '\0');
  char* dst = out.data();
  for (size_t i = 0; i < parts.size(); ++i) {
    if (i) {
      *dst++ = sep;
    }
    std::memcpy(dst, parts[i].data(), parts[i].size());
    dst = dst + parts[i].size();
  }
  return out;
}

int main(int argc, char** argv) {
  if (argc < 2) usage(2);
  std::map<std::string, Sev> rs{
      {"cx-regex-ctor-hot", Hint},
      {"cx-endl-hot", Hint},
      {"cx-clock-hot", Hint},
      {"cx-ifstream-hot", Hint},
      {"cx-const-by-value", Hint},
      {"cx-vector-bool", Hint}}; // CX001/CX003/CX004 removed 2026-10-22 — no slug
  std::string format = "text";
  bool strict_hints = false;
  bool no_fail = false;
  std::string scope = "all";
  std::vector<std::string> paths;
  paths.reserve(static_cast<size_t>(argc));

  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (a == "-h" || a == "--help") usage(0);
    if (a == "--format" && i + 1 < argc) {
      format = argv[++i];
      continue;
    }
    if (a.rfind("--format=", 0) == 0) {
      format = a.substr(9);
      continue;
    }
    if (a == "--severity" && i + 1 < argc) {
      if (!apply_sev(rs, argv[++i])) usage(2);
      continue;
    }
    if (a.rfind("--severity=", 0) == 0) {
      if (!apply_sev(rs, a.substr(11))) usage(2);
      continue;
    }
    if (a == "--strict-hints") {
      strict_hints = true;
      continue;
    }
    if (a == "--scope" && i + 1 < argc) {
      scope = argv[++i];
      if (scope != "all" && scope != "loop") usage(2);
      continue;
    }
    if (a.rfind("--scope=", 0) == 0) {
      scope = a.substr(8);
      if (scope != "all" && scope != "loop") usage(2);
      continue;
    }
    if (a == "--no-fail") {
      no_fail = true;
      continue;
    }
    if (!a.empty() && a[0] == '-') usage(2);
    paths.push_back(a);
  }
  if (paths.empty()) usage(2);

  std::vector<Finding> findings;
  findings.reserve(256);
  for (const auto& p : paths) {
    auto fs = scan_path(p, scope);
    findings.insert(findings.end(), fs.begin(), fs.end());
  }

  int nerr = 0, nhint = 0;
  std::vector<std::string> text_rows;
  std::vector<std::string> json_rows;
  text_rows.reserve(findings.size());
  json_rows.reserve(findings.size());

  for (const auto& f : findings) {
    Sev s = Hint;
    auto it = rs.find(f.rule);
    if (it != rs.end()) s = it->second;
    if (s == Off) continue;
    if (s == Error) ++nerr;
    else ++nhint;
    if (format == "json") {
      char buf[2048];
      std::snprintf(buf, sizeof(buf),
                    "{\"rule\":\"%s\",\"severity\":\"%s\",\"path\":\"%s\",\"line\":%d,\"message\":\"%s\"}",
                    f.rule.c_str(), sev_name(s), f.path.c_str(), f.line, f.message.c_str());
      json_rows.emplace_back(buf);
    } else {
      char buf[2048];
      std::snprintf(buf, sizeof(buf), "%s:%d: %s %s: %s", f.path.c_str(), f.line, sev_name(s),
                    f.rule.c_str(), f.message.c_str());
      text_rows.emplace_back(buf);
    }
  }

  if (format == "json") {
    std::string body = join_with_sep(json_rows, ',');
    std::string json;
    json.reserve(body.size() + 4);
    json = "[";
    json.insert(json.end(), body.begin(), body.end());
    json.insert(json.end(), {']', '\n'});
    std::cout << json;
  } else {
    if (!text_rows.empty()) {
      std::string joined = join_with_sep(text_rows, '\n');
      joined.insert(joined.end(), '\n');
      std::cout << joined;
    }
    int shown = nerr + nhint;
    if (shown) {
      std::cerr << shown << " finding(s) (" << nerr << " error, " << nhint << " hint)\n";
    } else {
      std::cerr << "ok\n";
    }
  }
  if (no_fail) return 0;
  if (nerr > 0 || (strict_hints && nhint > 0)) return 1;
  return 0;
}
