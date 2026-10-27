#include "cppperf_lint.hpp"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <regex>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static const std::regex re_for(R"(\bfor\s*\()");
static const std::regex re_while(R"(\bwhile\s*\()");
static std::string strip_line_comment(const std::string& s) {
  bool in_str = false;
  char q = 0;
  for (size_t i = 0; i < s.size(); ++i) {
    char c = s[i];
    if (in_str) {
      if (c == '\\' && i + 1 < s.size()) {
        ++i;
        continue;
      }
      if (c == q) in_str = false;
      continue;
    }
    if (c == '"' || c == '\'') {
      in_str = true;
      q = c;
      continue;
    }
    if (c == '/' && i + 1 < s.size() && s[i + 1] == '/') return s.substr(0, i);
  }
  return s;
}

static const std::regex re_std_regex_ctor(R"(\bstd::w?regex\s*[A-Za-z({\[])");
static const std::regex re_endl(R"((<<\s*(std::)?endl\b)|(\bstd::endl\b))");
static const std::regex re_clock(
    R"(\b((clock_gettime|gettimeofday)\s*\(|(steady_clock|system_clock|high_resolution_clock)::now\s*\())");
static const std::regex re_ifstream(R"(\bifstream\s*(?:\w+\s*)?\()");
// Declaration lines, not loop-gated. Backslashes keep these literals from matching themselves.
static const std::regex re_const_string_param(R"(\bconst\s+std::string\s+\w+\s*[,)])");
static const std::regex re_string_const_param(R"(\bstd::string\s+const\s+\w+\s*[,)])");
static const std::regex re_const_vector_param(
    R"(\bconst\s+std::vector\s*<[^>;\n]*>\s+\w+\s*[,)])");
static const std::regex re_vector_const_param(
    R"(\bstd::vector\s*<[^>;\n]*>\s+const\s+\w+\s*[,)])");
static const std::regex re_const_string_range(
    R"(\bfor\s*\(\s*const\s+std::string\s+\w+\s*:)");
static const std::regex re_string_const_range(
    R"(\bfor\s*\(\s*std::string\s+const\s+\w+\s*:)");
static const std::regex re_const_vector_range(
    R"(\bfor\s*\(\s*const\s+std::vector\s*<[^>;\n]*>\s+\w+\s*:)");
static const std::regex re_vector_const_range(
    R"(\bfor\s*\(\s*std::vector\s*<[^>;\n]*>\s+const\s+\w+\s*:)");
static const std::regex re_vector_bool(R"(\bvector\s*<\s*bool\s*>)");
static bool looks_const_by_value(const std::string& code) {
  return std::regex_search(code, re_const_string_param) ||
         std::regex_search(code, re_string_const_param) ||
         std::regex_search(code, re_const_vector_param) ||
         std::regex_search(code, re_vector_const_param) ||
         std::regex_search(code, re_const_string_range) ||
         std::regex_search(code, re_string_const_range) ||
         std::regex_search(code, re_const_vector_range) ||
         std::regex_search(code, re_vector_const_range);
}


static bool ident_char(char c) {
  return c == '_' || std::isalnum(static_cast<unsigned char>(c));
}

static bool ident_in(const std::string& s, const std::string& name) {
  if (name.empty()) return false;
  for (size_t i = 0; i + name.size() <= s.size();) {
    size_t j = s.find(name, i);
    if (j == std::string::npos) return false;
    bool before = j == 0 || !ident_char(s[j - 1]);
    size_t after = j + name.size();
    bool after_ok = after == s.size() || !ident_char(s[after]);
    if (before && after_ok) return true;
    i = j + 1;
  }
  return false;
}

static bool is_type_word(const std::string& w) {
  return w == "int" || w == "unsigned" || w == "long" || w == "short" || w == "char" ||
         w == "const" || w == "auto" || w == "size_t" || w == "struct" || w == "class" ||
         w == "volatile" || w == "signed" || w == "double" || w == "float" || w == "bool";
}

static std::vector<std::string> for_names(const std::string& code) {
  std::vector<std::string> names;
  size_t for_at = code.find("for");
  if (for_at == std::string::npos) return names;
  if (for_at > 0 && ident_char(code[for_at - 1])) return names;
  if (for_at + 3 < code.size() && ident_char(code[for_at + 3])) return names;
  size_t lp = code.find('(', for_at);
  if (lp == std::string::npos) return names;
  size_t rp = code.find(')', lp);
  if (rp == std::string::npos) return names;
  std::string head = code.substr(lp + 1, rp - lp - 1);
  size_t semi = head.find(';');
  if (semi != std::string::npos) head = head.substr(0, semi);
  size_t colon = head.find(':');
  if (colon != std::string::npos) head = head.substr(0, colon);
  size_t eq = head.find('=');
  if (eq != std::string::npos) head = head.substr(0, eq);
  std::string cur;
  std::string last;
  auto flush = [&]() {
    if (!cur.empty() && !is_type_word(cur)) last = cur;
    cur.clear();
  };
  for (char c : head) {
    if (ident_char(c)) cur.push_back(c);
    else flush();
  }
  flush();
  if (!last.empty()) names.push_back(last);
  return names;
}

static bool marker_arg_uses(const std::string& code, const char* marker, const std::vector<std::string>& names) {
  if (names.empty()) return false;
  size_t at = code.find(marker);
  if (at == std::string::npos) return false;
  size_t lp = code.find('(', at);
  if (lp == std::string::npos) return false;
  std::string args = code.substr(lp + 1);
  for (const auto& n : names) {
    if (ident_in(args, n)) return true;
  }
  return false;
}

std::vector<Finding> scan_file(const std::string& path, const std::string& scope = "all") {
  const std::string scope_mode = (scope == "loop") ? "loop" : "all";
  std::ifstream in(path);
  if (!in) return {};
  std::vector<std::string> lines;
  lines.reserve(512);
  {
    std::string line;
    while (std::getline(in, line)) {
      lines.push_back(line);
    }
  }
  // Pre-size finding buffer (historical CX001 self-hit guard; CX001 removed).
  std::vector<Finding> out;
  out.reserve(64);

  int depth = 0;
  int in_loop = 0;
  std::vector<std::string> loop_names;
  for (size_t idx = 0; idx < lines.size(); ++idx) {
    int line_no = static_cast<int>(idx + 1);
    std::string code = strip_line_comment(lines[idx]);

    int opens = static_cast<int>(std::count(code.begin(), code.end(), '{'));
    int closes = static_cast<int>(std::count(code.begin(), code.end(), '}'));

    bool loop_here = std::regex_search(code, re_for) || std::regex_search(code, re_while);
    if (loop_here) {
      in_loop = depth + 1;
      auto more = for_names(code);
      loop_names.insert(loop_names.end(), more.begin(), more.end());
    }

    const bool match_here = (scope_mode == "all") || (in_loop > 0 && depth >= in_loop);
    if (match_here) {
      // CX001/CX003/CX004 removed 2026-10-22 — ids tombstoned, do not reuse.
      if (std::regex_search(code, re_std_regex_ctor) && !marker_arg_uses(code, "regex", loop_names)) {
        out.push_back({"cx-regex-ctor-hot", path, line_no,
                       "regex object constructed; compile outside only when this pattern stays the same — cost adds up even off a hot path"});
      }
      if (std::regex_search(code, re_endl)) {
        out.push_back({"cx-endl-hot", path, line_no,
                       "stream flush manipulator; write a newline and flush once — cost adds up even off a hot path"});
      }
      if (std::regex_search(code, re_clock)) {
        out.push_back({"cx-clock-hot", path, line_no,
                       "clock sample in a tight loop; hoist only when this iteration does not need a fresh time"});
      }
      if (std::regex_search(code, re_ifstream) && !marker_arg_uses(code, "ifstream", loop_names)) {
        out.push_back({"cx-ifstream-hot", path, line_no,
                       "file stream opened; open once when the path stays the same — cost adds up even off a hot path"});
      }
      // CX003, CX004 removed 2026-10-22 — ids tombstoned.
    }

    // Not loop-gated: the copy is the parameter or the range-for head, and the
    // packed bool container is the type on the declaration line.
    if (looks_const_by_value(code)) {
      out.push_back({"cx-const-by-value", path, line_no,
                     "const string or vector copied by value; bind a const reference"});
    }
    if (std::regex_search(code, re_vector_bool)) {
      out.push_back({"cx-vector-bool", path, line_no,
                     "packed bool element container is slower to walk than a byte container"});
    }

    depth += opens - closes;
    if (depth < 0) depth = 0;
    if (in_loop > 0 && depth < in_loop) {
      in_loop = 0;
      loop_names.clear();
    }
  }
  return out;
}

static bool is_cpp(const fs::path& p) {
  auto e = p.extension().string();
  return e == ".cpp" || e == ".cc" || e == ".cxx" || e == ".hpp" || e == ".hh" || e == ".h";
}

// Corpus reverse-opt: skip test / vendored / bench / example trees that dominate noise.
static bool skip_dir(const std::string& name) {
  static const char* names[] = {
      ".git",       "fixtures",   "node_modules", "build",     ".build",
      "vendor",     "test",       "tests",        "Tests",     "third_party",
      "thirdparty", "benchmarks", "benchmark",    "bench",     "examples",
      "example",    "docs",       "gtest",        "gmock",     "doctest",
      "bundled",    nullptr};
  for (int i = 0; names[i]; ++i) {
    if (name == names[i]) return true;
  }
  return false;
}

std::vector<Finding> scan_path(const std::string& root, const std::string& scope = "all") {
  fs::path r(root);
  std::vector<Finding> all;
  all.reserve(128);
  std::error_code ec;
  if (fs::is_regular_file(r, ec)) {
    if (is_cpp(r)) return scan_file(r.string(), scope);
    return {};
  }
  // Collect file list first so walk itself is not a push_back hot loop of findings.
  std::vector<fs::path> files;
  files.reserve(256);
  for (auto it = fs::recursive_directory_iterator(r, ec);
       it != fs::recursive_directory_iterator(); ++it) {
    if (it->is_directory(ec)) {
      if (skip_dir(it->path().filename().string())) it.disable_recursion_pending();
      continue;
    }
    if (it->is_regular_file(ec) && is_cpp(it->path())) {
      files.push_back(it->path());
    }
  }
  for (const auto& fp : files) {
    auto fs_findings = scan_file(fp.string(), scope);
    all.insert(all.end(), fs_findings.begin(), fs_findings.end());
  }
  return all;
}
