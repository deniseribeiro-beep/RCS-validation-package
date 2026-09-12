CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Wpedantic
CPPFLAGS ?= -Iinclude
LDLIBS ?= -lm

REFERENCE_CORE_SOURCES := \
	src/rcs_reference.c \
	src/rcs_sprec.c \
	src/rcs_sprec_reference.c \
	src/rcs_governance.c \
	src/rcs_certification.c
REFERENCE_HEADERS := \
	include/rcs_reference.h \
	include/rcs_sprec.h \
	include/rcs_sprec_reference.h \
	include/rcs_governance.h \
	include/rcs_certification.h
REFERENCE_BIN := bin/rcs-reference
TEST_BIN := bin/test-reference

.PHONY: all reference test clean

all: reference

reference: $(REFERENCE_BIN)

$(REFERENCE_BIN): $(REFERENCE_CORE_SOURCES) src/rcs_reference_cli.c $(REFERENCE_HEADERS)
	mkdir -p bin
	$(CC) $(CPPFLAGS) $(CFLAGS) $(REFERENCE_CORE_SOURCES) src/rcs_reference_cli.c -o $(REFERENCE_BIN) $(LDLIBS)

$(TEST_BIN): $(REFERENCE_CORE_SOURCES) tests/test_reference.c $(REFERENCE_HEADERS)
	mkdir -p bin
	$(CC) $(CPPFLAGS) $(CFLAGS) $(REFERENCE_CORE_SOURCES) tests/test_reference.c -o $(TEST_BIN) $(LDLIBS)

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -f $(REFERENCE_BIN) $(TEST_BIN)
