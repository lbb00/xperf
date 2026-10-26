#include <chrono>
#include <ctime>
#include <sys/time.h>

void good(int n) {
  auto a = std::chrono::steady_clock::now();
  auto b = std::chrono::system_clock::now();
  auto c = std::chrono::high_resolution_clock::now();
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  struct timeval tv;
  gettimeofday(&tv, 0);
  for (int i = 0; i < n; ++i) {
    (void)a;
    (void)b;
    (void)c;
    (void)ts;
    (void)tv;
    (void)i;
  }
}
