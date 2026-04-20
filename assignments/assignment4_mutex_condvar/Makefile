# Programming Assignment 4: Fiber-level Mutex & Condition Variables
# Student Makefile

.PHONY: all build test clean help test-manual test-stm

all: build

build:
	dune build

test: test-manual test-stm

test-manual:
	@echo "=== Running Manual Tests ==="
	dune exec ./test_manual.exe

test-stm:
	@echo ""
	@echo "=== Running QCheck-STM Sequential Test ==="
	dune exec ./qcheck_stm_mutex.exe

clean:
	dune clean

help:
	@echo "Available targets:"
	@echo "  make build       - Build the project"
	@echo "  make test        - Run all tests"
	@echo "  make test-manual - Run manual (classic-problem) tests"
	@echo "  make test-stm    - Run QCheck-STM sequential test"
	@echo "  make clean       - Remove build artifacts"
