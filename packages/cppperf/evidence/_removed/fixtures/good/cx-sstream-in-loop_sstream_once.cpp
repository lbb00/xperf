#include <sstream>
#include <string>

std::string join(int n) {
  std::ostringstream ss;
  for (int i = 0; i < n; ++i) {
    ss << i;
  }
  return ss.str();
}
