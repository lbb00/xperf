# cppperf-lint — C++17 heuristic performance checker
CXX      ?= g++
CXXFLAGS ?= -std=c++17 -Wall -Wextra -O2 -g
LDFLAGS  ?=

SRCS := src/main.cpp src/scan.cpp
OBJS := $(SRCS:.cpp=.o)
BIN  := cppperf-lint

.PHONY: all clean test self-lint

all: $(BIN)

$(BIN): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(LDFLAGS)

src/%.o: src/%.cpp src/cppperf_lint.hpp
	$(CXX) $(CXXFLAGS) -Isrc -c -o $@ $<

clean:
	rm -f $(OBJS) $(BIN)

test: $(BIN)
	bash ../scripts/smoke-lint.sh

self-lint: $(BIN)
	bash ../scripts/self-lint.sh
