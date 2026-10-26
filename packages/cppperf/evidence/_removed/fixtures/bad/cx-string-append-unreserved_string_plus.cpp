#include <string>
std::string cat(const char* parts[], int n) {
  std::string s;
  for (int i = 0; i < n; ++i) {
    s += parts[i];
  }
  return s;
}
