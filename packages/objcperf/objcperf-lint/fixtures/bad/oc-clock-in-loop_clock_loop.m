#import <Foundation/Foundation.h>
static int bad(int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    NSDate *d = [NSDate date];
    s ^= (int)(d.timeIntervalSince1970 * 1000000) ^ i;
  }
  return s;
}
