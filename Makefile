CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Wpedantic
CPPFLAGS ?= -Iinclude
LDLIBS ?= -lm

REFERENCE_BIN := bin/rcs-reference
REFERENCE_SOURCES := src/rcs_reference.c src/rcs_sprec.c src/rcs_reference_cli.c
REFERENCE_HEADERS := include/rcs_reference.h include/rcs_sprec.h

.PHONY: all reference clean

all: reference

reference: $(REFERENCE_BIN)

$(REFERENCE_BIN): $(REFERENCE_SOURCES) $(REFERENCE_HEADERS)
	mkdir -p bin
	$(CC) $(CPPFLAGS) $(CFLAGS) $(REFERENCE_SOURCES) -o $(REFERENCE_BIN) $(LDLIBS)

clean:
	rm -f $(REFERENCE_BIN)
