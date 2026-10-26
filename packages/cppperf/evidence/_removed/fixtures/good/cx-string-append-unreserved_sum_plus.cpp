#include <cstdint>
#include <vector>
// cx-string-append-unreserved must stay quiet: numeric sum += (not string growth).
void accumulate(const std::vector<std::uint64_t>& n) {
  std::uint64_t sum = 0;
  for (auto v : n) {
    sum += v;
  }
  (void)sum;
}
