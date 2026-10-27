#import <Foundation/Foundation.h>

static NSUInteger count_keys(NSData *payload, NSString *keys[], NSUInteger n) {
  NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
  NSUInteger hits = 0;
  for (NSUInteger i = 0; i < n; i++) {
    // NSJSONSerialization JSONObjectWithData / dataWithJSONObject stays above.
    id value = [obj objectForKey:keys[i]];
    if (value) hits++;
  }
  return hits;
}

static NSData *encode_once(NSDictionary *item, NSUInteger n) {
  NSData *blob = [NSJSONSerialization dataWithJSONObject:item options:0 error:nil];
  NSUInteger bytes = [blob length];
  for (NSUInteger i = 0; i < n; i++) {
    bytes += i;
  }
  return blob;
}
