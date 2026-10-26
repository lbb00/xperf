#include <string>

std::string join(const char* parts[], int n) {
  std::string out;
  out.reserve(64);
  for (int i = 0; i < n; ++i) {
    out.append(parts[i]);
  }
  return out;
}

int main() {
  const char* parts[] = {"a", "b", "c"};
  auto s = join(parts, 3);
  return static_cast<int>(s.size());
}
