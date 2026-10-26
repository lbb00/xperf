CC ?= clang
CFLAGS ?= -std=c11 -Wall -Wextra -O2 -g
SRCS := src/main.c src/scan.c
OBJS := $(SRCS:.c=.o)
BIN := objcperf-lint

.PHONY: all clean test self-lint

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

src/%.o: src/%.c src/objcperf_lint.h
	$(CC) $(CFLAGS) -Isrc -c -o $@ $<

clean:
	rm -f $(OBJS) $(BIN)

test: $(BIN)
	bash ../scripts/smoke-lint.sh

self-lint: $(BIN)
	bash ../scripts/self-lint.sh
