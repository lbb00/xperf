#import <Foundation/Foundation.h>
NSString *good(NSUInteger n) {
  NSMutableString *s = [NSMutableString stringWithCapacity:n * 2];
  for (NSUInteger i = 0; i < n; i++) {
    [s appendString:[@(i) stringValue]];
  }
  return s;
}
