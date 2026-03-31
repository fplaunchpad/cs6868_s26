# Programming Assignment 3: Batch Bounded Blocking Queue
# Student Makefile

.PHONY: all build test clean help test-manual test-lin test-stm-seq test-stm-conc

all: build

build:
	dune build

test: test-manual test-lin test-stm-seq test-stm-conc

test-manual:
	@echo "=== Running Manual Tests ==="
	dune exec ./test_manual.exe

test-lin:
	@echo ""
	@echo "=== Running QCheck-Lin Linearizability Test ==="
	dune exec ./qcheck_lin_batch_queue.exe

test-stm-seq:
	@echo ""
	@echo "=== Running QCheck-STM Sequential Test ==="
	dune exec ./qcheck_stm_batch_queue.exe -- sequential

test-stm-conc:
	@echo ""
	@echo "=== Running QCheck-STM Concurrent Test ==="
	dune exec ./qcheck_stm_batch_queue.exe -- concurrent

clean:
	dune clean

help:
	@echo "Available targets:"
	@echo "  make build         - Build the project"
	@echo "  make test          - Run all tests"
	@echo "  make test-manual   - Run manual concurrent tests"
	@echo "  make test-lin      - Run QCheck-Lin linearizability test"
	@echo "  make test-stm-seq  - Run QCheck-STM sequential test"
	@echo "  make test-stm-conc - Run QCheck-STM concurrent test"
	@echo "  make clean         - Remove build artifacts"
