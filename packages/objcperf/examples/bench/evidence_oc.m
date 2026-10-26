#import <Foundation/Foundation.h>
#import <stdio.h>
#import <stdlib.h>
#import <time.h>

static double median(double *a, int n) {
  int i, j;
  for (i = 0; i < n; i++)
    for (j = i + 1; j < n; j++)
      if (a[j] < a[i]) { double t = a[i]; a[i] = a[j]; a[j] = t; }
  if (n % 2) return a[n / 2];
  return 0.5 * (a[n / 2 - 1] + a[n / 2]);
}

static double time_many(int (*fn)(void)) {
  const int WARM = 3, ROUNDS = 9;
  int i, r, sink = 0;
  double samples[9];
  for (i = 0; i < WARM; i++) fn();
  for (r = 0; r < ROUNDS; r++) {
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    sink += fn();
    clock_gettime(CLOCK_MONOTONIC, &t1);
    samples[r] = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
  }
  if (sink == 0x7fffffff) exit(2);
  return median(samples, ROUNDS);
}

static int N4;
static NSArray *SRC4;

static int bad_empty_add(void) {
  NSMutableArray *out = [NSMutableArray array];
  id x;
  NSEnumerator *e = [SRC4 objectEnumerator];
  while ((x = [e nextObject])) [out addObject:x];
  return (int)[out count];
}
static int good_capacity(void) {
  NSMutableArray *out = [NSMutableArray arrayWithCapacity:[SRC4 count]];
  id x;
  NSEnumerator *e = [SRC4 objectEnumerator];
  while ((x = [e nextObject])) [out addObject:x];
  return (int)[out count];
}

static int N2;
static int bad_append(void) {
  NSString *s = @"";
  int i;
  for (i = 0; i < N2; i++)
    s = [s stringByAppendingFormat:@"%d", i];
  return (int)[s length];
}
static int good_mutable(void) {
  NSMutableString *s = [NSMutableString stringWithCapacity:(unsigned)(N2 * 4)];
  int i;
  for (i = 0; i < N2; i++)
    [s appendFormat:@"%d", i];
  return (int)[s length];
}

static int N3;
static int bad_nslog(void) {
  int i, s = 0;
  for (i = 0; i < N3; i++) { fprintf(stderr, "%d\n", i); s += i; }
  return s;
}
static int good_nslog_once(void) {
  int i, s = 0;
  for (i = 0; i < N3; i++) s += i;
  fprintf(stderr, "%d\n", s);
  return s;
}

static void emit(const char *dir, const char *rule, const char *after_case, double after_ms, int after_ops,
                 const char *before_case, double before_ms, int before_ops) {
  char path[512];
  FILE *f;
  time_t now;
  struct tm tm;
  char ts[64];
  snprintf(path, sizeof path, "%s/%s.jsonl", dir, rule);
  f = fopen(path, "w");
  if (!f) { perror(path); exit(1); }
  now = time(NULL);
  gmtime_r(&now, &tm);
  strftime(ts, sizeof ts, "%Y-%m-%dT%H:%M:%SZ", &tm);
  fprintf(f,
    "{\"rule\":\"%s\",\"case\":\"%s\",\"role\":\"after\",\"runtime\":\"gnustep\",\"median_ms\":%.6f,\"ops\":%d,\"ratio\":1,\"ts\":\"%s\"}\n"
    "{\"rule\":\"%s\",\"case\":\"%s\",\"role\":\"before\",\"runtime\":\"gnustep\",\"median_ms\":%.6f,\"ops\":%d,\"ratio\":%.6f,\"ts\":\"%s\"}\n",
    rule, after_case, after_ms, after_ops, ts,
    rule, before_case, before_ms, before_ops, before_ms / after_ms, ts);
  fclose(f);
  printf("wrote %s  before=%.4f after=%.4f ratio=%.3f\n", path, before_ms, after_ms, before_ms / after_ms);
}

int main(void) {
  const char *dir = getenv("EVIDENCE_DIR");
  NSAutoreleasePool *pool;
  NSMutableArray *tmp;
  int i;
  double after4, before4, after2, before2, after3, before3;
  if (!dir) dir = "../../evidence"; /* relative to examples/bench */
  pool = [[NSAutoreleasePool alloc] init];

  N4 = getenv("OC004_N") ? atoi(getenv("OC004_N")) : 200000;
  tmp = [NSMutableArray arrayWithCapacity:N4];
  for (i = 0; i < N4; i++) [tmp addObject:[NSNumber numberWithInt:i]];
  SRC4 = tmp;
  after4 = time_many(good_capacity);
  before4 = time_many(bad_empty_add);
  emit(dir, "OC004", "array_with_capacity", after4, N4, "empty_addObject", before4, N4);
  emit(dir, "OC001", "array_with_capacity", after4, N4, "add_loop_empty", before4, N4);

  N2 = getenv("OC002_N") ? atoi(getenv("OC002_N")) : 15000;
  after2 = time_many(good_mutable);
  before2 = time_many(bad_append);
  emit(dir, "oc-nsstring-append-in-loop", "mutable_string", after2, N2, "stringByAppending", before2, N2);

  N3 = getenv("OC003_N") ? atoi(getenv("OC003_N")) : 10000;
  freopen("/dev/null", "w", stderr);
  before3 = time_many(bad_nslog);
  after3 = time_many(good_nslog_once);
  emit(dir, "oc-nslog-in-loop", "log_once", after3, N3, "fprintf_in_loop", before3, N3);

  [pool release];
  return 0;
}
