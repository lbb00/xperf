#import <Foundation/Foundation.h>
void bad(NSUInteger n) {
  for (NSUInteger i = 0; i < n; i++) {
    NSLog(@"%lu", (unsigned long)i);
  }
}
