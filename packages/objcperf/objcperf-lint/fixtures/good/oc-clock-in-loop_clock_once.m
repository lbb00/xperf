#import <Foundation/Foundation.h>
static int good(int n) {
  NSDate *d = [NSDate date];
  int t = (int)(d.timeIntervalSince1970 * 1000000);
  int s = 0;
  for (int i = 0; i < n; i++) {
    s ^= t ^ i;
  }
  return s;
}
