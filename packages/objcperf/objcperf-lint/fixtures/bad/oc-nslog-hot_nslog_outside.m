#import <Foundation/Foundation.h>
NSUInteger good(NSUInteger n) {
  NSUInteger s = 0;
  for (NSUInteger i = 0; i < n; i++) {
    s += i;
  }
  NSLog(@"%lu", (unsigned long)s);
  return s;
}
