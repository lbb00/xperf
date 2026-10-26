#include <sstream>
#include <string>

int join(int n) {
  int total = 0;
  for (int i = 0; i < n; ++i) {
    std::ostringstream ss;
    ss << i;
    total += static_cast<int>(ss.str().size());
  }
  return total;
}
