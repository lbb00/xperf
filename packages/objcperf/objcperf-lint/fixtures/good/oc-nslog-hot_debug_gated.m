#import <Foundation/Foundation.h>
void inspectOpen(NSSet *openSetCopy) {
#if defined(DEBUG) && DEBUG
  for (NSValue *v in openSetCopy) {
    NSLog(@"query: '%@'", v);
  }
#endif
}

void bindTrace(NSDictionary *dictionaryArgs, BOOL _traceExecution) {
  for (NSString *dictionaryKey in [dictionaryArgs allKeys]) {
    if (_traceExecution) {
      NSLog(@"%@ = %@", dictionaryKey, dictionaryArgs[dictionaryKey]);
    }
  }
}
