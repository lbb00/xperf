#include <regex>
#include <string>

void find_all(const std::string& text, const std::string pats[], int n) {
  std::regex re("a+");
  for (int i = 0; i < n; ++i) {
    (void)std::regex_search(text, re);
    (void)pats[i];
  }
}
