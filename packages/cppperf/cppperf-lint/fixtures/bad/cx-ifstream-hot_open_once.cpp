#include <fstream>
int good(int n) {
  std::ifstream in("one.txt");
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = in.good() ? 1 : 0;
  }
  return s;
}
