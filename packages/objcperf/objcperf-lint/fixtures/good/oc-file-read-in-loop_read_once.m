#import <Foundation/Foundation.h>
static int good(NSString *path, int n) {
  NSString *d = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
  int s = 0;
  for (int i = 0; i < n; i++) {
    s = (int)d.length;
  }
  return s;
}
