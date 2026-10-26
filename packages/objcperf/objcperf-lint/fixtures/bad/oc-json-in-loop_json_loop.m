#import <Foundation/Foundation.h>

static id bad_parse(NSData *chunk, NSUInteger n) {
  id last = nil;
  for (NSUInteger i = 0; i < n; i++) {
    last = [NSJSONSerialization JSONObjectWithData:chunk options:0 error:nil];
  }
  return last;
}

static NSData *bad_encode(id item, NSUInteger n) {
  NSData *last = nil;
  for (NSUInteger i = 0; i < n; i++) {
    last = [NSJSONSerialization dataWithJSONObject:item options:0 error:nil];
  }
  return last;
}
