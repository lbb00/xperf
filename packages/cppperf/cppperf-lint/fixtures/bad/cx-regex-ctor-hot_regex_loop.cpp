#include <regex>
#include <string>

void find_all(const std::string& text, int n) {
  for (int i = 0; i < n; ++i) {
    std::regex re("a+");
    (void)std::regex_search(text, re);
  }
}
