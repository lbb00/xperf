#include <fstream>
int bad(int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    std::ifstream in("one.txt");
    s = in.good() ? 1 : 0;
  }
  return s;
}
