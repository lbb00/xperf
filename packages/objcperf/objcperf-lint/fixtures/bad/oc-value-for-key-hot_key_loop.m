static int bad(id b, int n) {
  int acc = 0;
  for (int i = 0; i < n; i++) {
    acc = [[b valueForKey:@"a"] intValue];
  }
  return acc;
}
