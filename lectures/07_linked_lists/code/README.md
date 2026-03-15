# Linked Lists — Concurrent Set Implementations

This directory contains OCaml implementations of concurrent linked-list-based sets from "The Art of Multiprocessor Programming" Chapter 9.

The implementations form a progression from coarse-grained locking to lock-free, each improving concurrency at the cost of additional complexity.

## Code Structure

### Core Implementations (`lib/`)

- **`seq_list.ml`** — Sequential (non-concurrent) sorted linked list. Baseline for correctness.
- **`coarse_list.ml`** — Coarse-grained synchronization. A single mutex protects the entire list.
- **`fine_list.ml`** — Fine-grained synchronization. Hand-over-hand (lock coupling) locking: lock two adjacent nodes at a time, then advance.
- **`optimistic_list.ml`** — Optimistic synchronization. Traverse without locks, then lock and *validate* before modifying. Faster traversal, but validation can fail.
- **`optimistic_list_racefree.ml`** — Race-free variant of the optimistic list with additional safety for OCaml's memory model.
- **`lazy_list.ml`** — Lazy synchronization. Logical deletion via a mark bit before physical removal. `contains()` is wait-free (no locks).
- **`lazy_list_racefree.ml`** — Race-free variant of the lazy list.
- **`lockfree_list.ml`** — Lock-free list (Michael's algorithm). Uses `AtomicMarkableReference` to combine the mark bit and next pointer in a single atomic update. No locks at all.
- **`atomic_markable_ref.ml`** — Helper module implementing `AtomicMarkableReference` (a reference + mark bit updated atomically), used by the lock-free list.

### Tests (`test/`)

Each implementation has up to three levels of testing:

- **`test_*.ml`** — Sequential and concurrent unit tests
- **`qcheck_lin_*.ml`** — QCheck-Lin linearizability tests
- **`qcheck_stm_*.ml`** — QCheck-STM state-machine tests against a sequential model

### Benchmarks (`benchmarks/`)

- **`benchmark_lists.ml`** — Throughput comparison across all list implementations
- **`run_benchmarks.sh`** — Script to run benchmarks
- **`plot_results.py`** — Plot benchmark results

## Progression of Techniques

| Implementation | Locking | `add`/`remove` | `contains` | Progress |
|---------------|---------|----------------|------------|----------|
| Sequential | None | — | — | — |
| Coarse | Single global lock | Lock entire list | Lock entire list | Blocking |
| Fine-grained | Per-node locks | Hand-over-hand | Hand-over-hand | Blocking |
| Optimistic | Per-node locks | Lock + validate | Lock + validate | Blocking |
| Lazy | Per-node locks | Lock + mark | Wait-free (no lock!) | `contains` wait-free |
| Lock-free | None (CAS) | CAS + mark | Wait-free | Lock-free |

## Building and Running

```bash
# Build everything
dune build

# Run individual tests
dune exec test/test_seq_list.exe
dune exec test/test_coarse_list.exe
dune exec test/test_fine_list.exe
dune exec test/test_optimistic_list.exe
dune exec test/test_lazy_list.exe
dune exec test/test_lockfree_list.exe

# Run linearizability tests
dune exec test/qcheck_lin_coarse_list.exe
dune exec test/qcheck_lin_fine_list.exe
dune exec test/qcheck_lin_optimistic_list.exe
dune exec test/qcheck_lin_lazy_list.exe
dune exec test/qcheck_lin_lockfree_list.exe

# Run STM tests
dune exec test/qcheck_stm_coarse_list.exe -- all
dune exec test/qcheck_stm_fine_list.exe -- all
dune exec test/qcheck_stm_lockfree_list.exe -- all

# Run benchmarks
cd benchmarks && bash run_benchmarks.sh
```

## Project Structure

```
code/
├── lib/
│   ├── seq_list.ml/mli                 # Sequential baseline
│   ├── coarse_list.ml/mli              # Single-lock list
│   ├── fine_list.ml/mli                # Hand-over-hand locking
│   ├── optimistic_list.ml/mli          # Optimistic + validation
│   ├── optimistic_list_racefree.ml/mli # Race-free optimistic
│   ├── lazy_list.ml/mli               # Lazy deletion (wait-free contains)
│   ├── lazy_list_racefree.ml/mli      # Race-free lazy
│   ├── lockfree_list.ml/mli           # Lock-free (Michael's algorithm)
│   ├── atomic_markable_ref.ml/mli     # AtomicMarkableReference helper
│   └── dune
├── test/
│   ├── test_*.ml                       # Unit tests
│   ├── qcheck_lin_*.ml                 # Linearizability tests
│   ├── qcheck_stm_*.ml                # State-machine tests
│   └── dune
├── benchmarks/
│   ├── benchmark_lists.ml              # Throughput benchmark
│   ├── run_benchmarks.sh
│   ├── plot_results.py
│   └── dune
└── README.md
```
