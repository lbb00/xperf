#include <regex>
#include <string>

void find_all(const std::string& text, const std::string pats[], int n) {
  for (int i = 0; i < n; ++i) {
    std::regex re(pats[i]);
    (void)std::regex_search(text, re);
  }
}
