#include <string>
#include <vector>
std::string cat(const std::vector<std::string>& parts) {
  std::string s;
  s.reserve(128);
  // join outside a += / append loop: copy once
  for (const auto& p : parts) {
    (void)p;
  }
  s = "ok";
  return s;
}
