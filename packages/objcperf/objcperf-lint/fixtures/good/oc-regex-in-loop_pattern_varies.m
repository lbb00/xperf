#import <Foundation/Foundation.h>

static NSUInteger good_compile(NSString *pats[], NSString *texts[], NSUInteger n) {
  NSUInteger hits = 0;
  for (NSUInteger i = 0; i < n; i++) {
    NSError *err = nil;
    NSRegularExpression *re =
        [NSRegularExpression regularExpressionWithPattern:pats[i] options:0 error:&err];
    NSRange range = NSMakeRange(0, [texts[i] length]);
    hits += [re numberOfMatchesInString:texts[i] options:0 range:range];
  }
  return hits;
}
