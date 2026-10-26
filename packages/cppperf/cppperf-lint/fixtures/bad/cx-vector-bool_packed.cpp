#include <vector>

int walk(int n) {
  std::vector<bool> bits(static_cast<size_t>(n));
  int c = 0;
  for (int i = 0; i < n; ++i) {
    if (bits[static_cast<size_t>(i)]) ++c;
  }
  return c;
}
