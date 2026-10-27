#import <Foundation/Foundation.h>

static NSString *bad_alloc(NSDate *dates[], NSUInteger n) {
  NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
  for (NSUInteger i = 0; i < n; i++) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"yyyy-MM-dd"];
    [out addObject:[fmt stringFromDate:dates[i]]];
  }
  return [out componentsJoinedByString:@","];
}

static NSString *bad_new(NSDate *dates[], NSUInteger n) {
  NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
  for (NSUInteger i = 0; i < n; i++) {
    NSDateFormatter *fmt = [NSDateFormatter new];
    [fmt setDateFormat:@"yyyy-MM-dd"];
    [out addObject:[fmt stringFromDate:dates[i]]];
  }
  return [out componentsJoinedByString:@","];
}
