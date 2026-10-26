#include <fstream>
#include <string>
int good(const std::string paths[], int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    std::ifstream in(paths[i]);
    s = in.good() ? 1 : 0;
  }
  return s;
}
