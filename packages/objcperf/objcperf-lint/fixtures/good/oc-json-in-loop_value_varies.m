#import <Foundation/Foundation.h>

static id good_parse(NSData *chunks[], NSUInteger n) {
  id last = nil;
  for (NSUInteger i = 0; i < n; i++) {
    last = [NSJSONSerialization JSONObjectWithData:chunks[i] options:0 error:nil];
  }
  return last;
}
