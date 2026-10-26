#include <cstddef>
std::size_t sum_bytes(const int* writes, int n) {
  std::size_t bytes_sent = 0;
  for (int i = 0; i < n; ++i) {
    bytes_sent += static_cast<std::size_t>(writes[i]);
  }
  return bytes_sent;
}
