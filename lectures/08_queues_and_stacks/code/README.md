# Queues and Stacks — Lock-Free and Bounded Implementations

This directory contains OCaml implementations of concurrent queues and stacks from "The Art of Multiprocessor Programming" Chapters 10–11.

## Code Structure

### Core Implementations (`lib/`)

#### Queues (Chapter 10)

- **`bounded_queue.ml`** — Bounded blocking queue. Separate enqueue/dequeue locks with condition variables, and an atomic size counter. Allows concurrent enqueue and dequeue.
- **`bounded_queue_split_counter.ml`** — Bounded queue with split-counter optimization. Splits the shared `size` counter into `enq_side_size` and `deq_side_size` to reduce cache-line contention between producers and consumers.
- **`lockfree_queue.ml`** — Michael-Scott lock-free queue. Two-step lazy enqueue (append node, then swing tail). Every operation helps complete pending enqueues.

#### Stacks (Chapter 11)

- **`lockfree_stack.ml`** — Treiber stack with exponential backoff. Custom node type with an `Atomic.t` `top` pointer (Figures 11.2–11.4).
- **`lockfree_stack_builtin_list.ml`** — Functional Treiber stack. Same algorithm but uses OCaml's immutable `'a list` in an `Atomic.t` — no custom node type needed.
- **`backoff.ml`** — Exponential backoff shared by the two Treiber stacks, plus a `No_backoff` module used for model checking.
- **`atomic_intf.ml`** — The atomic operations the Treiber stacks need. Both stacks are `Make` functors over it and over `Backoff.S`, so the same code runs on `Stdlib.Atomic` (the default `Lockfree_stack` / `Lockfree_stack_builtin_list` modules) or on DSCheck's traced atomics.
- **`lockfree_exchanger.ml`** — Lock-free exchanger (Figure 11.6). Single-slot rendezvous for two threads to swap values. Three states (`Empty | Waiting of 'a | Busy of 'a`) encoded as a variant in a plain `Atomic.t` — the variant tag replaces Java's `AtomicStampedReference`. Uses `Atomic.make_contended` for cache-line padding.
- **`elimination_array.ml`** — Elimination array (Figure 11.7). Array of `LockFreeExchanger` slots. Each `visit` picks a random slot in a caller-chosen subrange.
- **`elimination_backoff_stack.ml`** — Elimination backoff stack (Figures 11.8–11.9). Combines a Treiber stack with an `EliminationArray`. Under low contention, operations complete via CAS on `top`. Under high contention, complementary push/pop pairs "eliminate" each other through the array without touching the shared stack. Domain-local range policy adapts to load.

### Tests (`test/`)

Each implementation has up to four levels of testing:

- **`test_*.ml`** — Sequential and concurrent unit tests
- **`qcheck_lin_*.ml`** — QCheck-Lin linearizability tests
- **`qcheck_stm_*.ml`** — QCheck-STM state-machine tests against a sequential model
- **`dscheck_*.ml`** — [DSCheck](https://github.com/ocaml-multicore/dscheck) model-checking tests. Instead of running threads and hoping for a bad schedule, DSCheck exhaustively explores every interleaving of a few concurrent operations. For it to see those interleavings, the implementation under test is instantiated with DSCheck's traced atomics via its `Make` functor (see `atomic_intf.ml`), with backoff disabled since model checking needs deterministic runs. Each file ends with a *negative* test that builds the same code on a deliberately non-atomic CAS and checks that DSCheck finds the resulting bug.

### Benchmarks (`test/`)

- **`benchmark_stacks.ml`** — Throughput comparison: Treiber stack vs elimination backoff stack under increasing thread counts
- **`benchmark_queues.ml`** — Throughput comparison: bounded queue vs split-counter bounded queue vs lock-free (Michael-Scott) queue. Capacity is set to total items so the bounded queues never block on fullness, giving a fair comparison with the unbounded lock-free queue

## Key Design Choices (OCaml vs Java)

| Java | OCaml |
|------|-------|
| `AtomicStampedReference<T>` (allocates internal pair per CAS) | Variant type `Empty \| Waiting of 'a \| Busy of 'a` in plain `Atomic.t` — tag is the stamp |
| `ThreadLocal<RangePolicy>` | `Domain.DLS` (domain-local storage) |
| `ThreadLocalRandom` | `Random.int` (domain-local since OCaml 5) |
| `System.nanoTime()` timeout | Bounded iteration count with `Domain.cpu_relax()` |
| `AtomicMarkableReference` array | Array of `Atomic.t` with `Atomic.make_contended` padding |

## Building and Running

```bash
# Build everything
dune build

# Run stack tests
dune exec test/test_lockfree_stack.exe
dune exec test/test_lockfree_stack_builtin_list.exe
dune exec test/test_elimination_backoff_stack.exe

# Run queue tests
dune exec test/test_lockfree_queue.exe
dune exec test/test_bounded_queue.exe
dune exec test/test_bounded_queue_split_counter.exe

# Run linearizability tests
dune exec test/qcheck_lin_lockfree_stack.exe
dune exec test/qcheck_lin_elimination_backoff_stack.exe
dune exec test/qcheck_lin_lockfree_queue.exe
dune exec test/qcheck_lin_bounded_queue.exe

# Run STM tests
dune exec test/qcheck_stm_lockfree_stack.exe -- all
dune exec test/qcheck_stm_elimination_backoff_stack.exe -- all
dune exec test/qcheck_stm_lockfree_queue.exe -- all

# Run DSCheck model-checking tests
dune exec test/dscheck_lockfree_stack.exe
dune exec test/dscheck_lockfree_stack_builtin_list.exe

# Run benchmarks
dune exec test/benchmark_stacks.exe
dune exec test/benchmark_stacks.exe -- --ops 200000 --max-threads 8 --runs 5
dune exec test/benchmark_queues.exe
dune exec test/benchmark_queues.exe -- --ops 200000 --max-threads 8 --runs 5
```

## Project Structure

```
code/
├── lib/
│   ├── bounded_queue.ml/mli                # Bounded blocking queue
│   ├── bounded_queue_split_counter.ml/mli  # Split-counter variant
│   ├── lockfree_queue.ml/mli              # Michael-Scott queue
│   ├── lockfree_stack.ml/mli              # Treiber stack (custom nodes)
│   ├── lockfree_stack_builtin_list.ml/mli # Treiber stack (immutable list)
│   ├── lockfree_exchanger.ml/mli          # Lock-free exchanger
│   ├── elimination_array.ml/mli           # Array of exchangers
│   ├── elimination_backoff_stack.ml/mli   # Elimination backoff stack
│   └── dune
├── test/
│   ├── test_*.ml                           # Unit tests
│   ├── qcheck_lin_*.ml                     # Linearizability tests
│   ├── qcheck_stm_*.ml                     # State-machine tests
│   ├── benchmark_stacks.ml                 # Stack throughput benchmark
│   ├── benchmark_queues.ml                 # Queue throughput benchmark
│   └── dune
└── README.md
```
