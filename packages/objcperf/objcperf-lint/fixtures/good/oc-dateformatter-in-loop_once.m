#import <Foundation/Foundation.h>

static NSString *format_with_alloc(NSDate *dates[], NSUInteger n) {
  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  [fmt setDateFormat:@"yyyy-MM-dd"];
  NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
  for (NSUInteger i = 0; i < n; i++) {
    // NSDateFormatter alloc / [NSDateFormatter new] stays outside this loop.
    NSDateFormatter *same = fmt;
    [out addObject:[same stringFromDate:dates[i]]];
  }
  return [out componentsJoinedByString:@","];
}

static NSString *format_with_new(NSDate *dates[], NSUInteger n) {
  NSDateFormatter *fmt = [NSDateFormatter new];
  [fmt setDateFormat:@"yyyy-MM-dd"];
  NSMutableArray *out = [NSMutableArray arrayWithCapacity:n];
  for (NSUInteger i = 0; i < n; i++) {
    [out addObject:[fmt stringFromDate:dates[i]]];
  }
  return [out componentsJoinedByString:@","];
}
