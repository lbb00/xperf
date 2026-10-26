#import <Foundation/Foundation.h>
static int bad(NSString *path, int n) {
  int s = 0;
  for (int i = 0; i < n; i++) {
    NSString *d = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    s = (int)d.length;
  }
  return s;
}
