#import <Foundation/Foundation.h>
NSString *bad(NSUInteger n) {
  NSString *s = @"";
  for (NSUInteger i = 0; i < n; i++) {
    s = [s stringByAppendingString:[@(i) stringValue]];
  }
  return s;
}
