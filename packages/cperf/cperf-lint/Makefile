# cperf-lint — C11 heuristic performance checker
CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -O2 -g
CPPFLAGS += -Iinclude -D_GNU_SOURCE
LDFLAGS ?=

SRCS := src/main.c src/scan.c src/pathwalk.c src/util.c
OBJS := $(SRCS:.c=.o)
BIN  := cperf-lint

.PHONY: all clean test self-lint smoke install

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

src/%.o: src/%.c include/cperf_lint.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(BIN)

smoke: $(BIN)
	@set +e; \
	./$(BIN) fixtures/bad --format text; b=$$?; \
	./$(BIN) fixtures/good --scope loop --format text; g=$$?; \
	./$(BIN) fixtures/bad/cp-printf-hot_printf_loop.c --preset app; a3=$$?; \
	./$(BIN) fixtures/bad/cp-printf-hot_printf_loop.c --preset all; A3=$$?; \
	./$(BIN) fixtures/bad/cp-printf-hot_printf_loop.c --preset app --strict-hints; s3=$$?; \
	./$(BIN) fixtures/bad/cp-alloc-hot_malloc_loop.c --preset app; a1=$$?; \
	./$(BIN) fixtures/bad/cp-realloc-grow-one_realloc_grow.c --preset app; a2=$$?; \
	./$(BIN) fixtures/bad/cp-strlen-in-cond_strlen_cond.c --preset app; a4=$$?; \
	./$(BIN) fixtures/bad/cp-strlen-in-cond_strlen_cond.c --preset app --strict-hints; s4=$$?; \
	./$(BIN) fixtures/bad/cp-strcat-hot_strcat_loop.c --severity cp-strcat-hot=hint; a5=$$?; \
	./$(BIN) fixtures/bad/cp-strcat-hot_strcat_loop.c --preset app; a5off=$$?; \
	set -e; \
	[ "$$b" -eq 1 ] || { echo "expected bad exit 1 got $$b"; exit 1; }; \
	[ "$$g" -eq 0 ] || { echo "expected good exit 0 got $$g"; exit 1; }; \
	[ "$$a3" -eq 0 ] || { echo "app cp-printf-hot-only should exit 0 (hint) got $$a3"; exit 1; }; \
	[ "$$A3" -eq 1 ] || { echo "all cp-printf-hot-only should exit 1 got $$A3"; exit 1; }; \
	[ "$$s3" -eq 0 ] || { echo "app cp-printf-hot is off; strict-hints should exit 0 got $$s3"; exit 1; }; \
	[ "$$a1" -eq 1 ] || { echo "app cp-alloc-hot should exit 1 got $$a1"; exit 1; }; \
	[ "$$a2" -eq 1 ] || { echo "app cp-realloc-grow-one-only should exit 1 (error) got $$a2"; exit 1; }; \
	[ "$$a4" -eq 0 ] || { echo "app cp-strlen-in-cond-only should exit 0 (hint) got $$a4"; exit 1; }; \
	[ "$$s4" -eq 1 ] || { echo "app cp-strlen-in-cond strict-hints should exit 1 got $$s4"; exit 1; }; \
	[ "$$a5" -eq 0 ] || { echo "cp-strcat-hot=hint should exit 0 got $$a5"; exit 1; }; \
	[ "$$a5off" -eq 0 ] || { echo "app cp-strcat-hot off should exit 0 got $$a5off"; exit 1; }; \
	./$(BIN) fixtures/bad/cp-strcat-hot_strcat_loop.c --severity cp-strcat-hot=hint --format text --no-fail | grep -q cp-strcat-hot || { echo "cp-strcat-hot fixture must fire when enabled"; exit 1; }; \
	echo "cperf-lint smoke ok"

# Self-lint: clean under --scope loop (one-shot tool allocs are intentional;
# default CLI remains --scope all for adopters).
self-lint: $(BIN)
	./$(BIN) src include --scope loop --format text
	@echo "cperf-lint self-lint ok"

test: smoke self-lint

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

PREFIX ?= /usr/local
