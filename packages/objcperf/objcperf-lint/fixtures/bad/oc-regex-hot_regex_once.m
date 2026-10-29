#import <Foundation/Foundation.h>

static NSUInteger count_hits(NSString *texts[], NSUInteger n) {
  NSError *err = nil;
  NSRegularExpression *re =
      [NSRegularExpression regularExpressionWithPattern:@"a+" options:0 error:&err];
  NSUInteger hits = 0;
  for (NSUInteger i = 0; i < n; i++) {
    // NSRegularExpression regularExpressionWithPattern stays above.
    NSRegularExpression *same = re;
    NSRange range = NSMakeRange(0, [texts[i] length]);
    hits += [same numberOfMatchesInString:texts[i] options:0 range:range];
  }
  return hits;
}
