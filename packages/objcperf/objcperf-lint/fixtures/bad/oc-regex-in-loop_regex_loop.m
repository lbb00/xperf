#import <Foundation/Foundation.h>

static NSUInteger bad_compile(NSString *texts[], NSUInteger n) {
  NSUInteger hits = 0;
  for (NSUInteger i = 0; i < n; i++) {
    NSError *err = nil;
    NSRegularExpression *re =
        [NSRegularExpression regularExpressionWithPattern:@"[0-9]+" options:0 error:&err];
    NSRange range = NSMakeRange(0, [texts[i] length]);
    hits += [re numberOfMatchesInString:texts[i] options:0 range:range];
  }
  return hits;
}
