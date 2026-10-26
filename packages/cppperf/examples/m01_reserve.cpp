#include <vector>

std::vector<int> build(int n) {
  std::vector<int> v;
  v.reserve(static_cast<size_t>(n));
  for (int i = 0; i < n; ++i) {
    v.push_back(i);
  }
  return v;
}

int main() {
  auto v = build(8);
  return static_cast<int>(v.size());
}
