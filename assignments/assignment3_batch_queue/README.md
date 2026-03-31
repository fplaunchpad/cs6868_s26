# Programming Assignment 3: Batch Bounded Blocking Queue

**Points:** 100

## Learning Objectives

This assignment focuses on **synchronization with locks and condition variables**. You will:

1. Implement a bounded blocking queue with **batch atomic operations**
2. Enforce **FIFO fairness** with head-of-line blocking for both enqueuers and dequeuers
3. Use **per-waiter condition variables** for efficient signaling
4. Write concurrent correctness tests
5. Write property-based linearizability tests using **QCheck-Lin** and **QCheck-STM**

---

## Prerequisites

Make sure your OCaml environment is set up. The packages required:

```bash
opam install qcheck-lin qcheck-stm
```

---

## Background

### Batch Bounded Blocking Queue

A **batch bounded blocking queue** extends a standard bounded queue with two key features:

1. **Batch operations**: `enq` and `deq` operate on multiple elements atomically. `enq` takes an array of items and enqueues all of them in one operation. `deq(n)` dequeues exactly `n` items as an array.

2. **FIFO fairness with head-of-line blocking**: When multiple threads are blocked waiting to enqueue or dequeue, they are served strictly in arrival order. A smaller request **cannot jump ahead** of a larger one, even if it could be satisfied immediately.

### Example: Dequeue Head-of-Line Blocking

Queue is empty. Thread A calls `deq(5)` and blocks. Thread B calls `deq(2)` and blocks behind A. An enqueuer adds 6 items. Only `deq(5)` is satisfied (A arrived first). The remaining 1 item is not enough for `deq(2)`, so B stays blocked.

### Example: Enqueue Head-of-Line Blocking

Queue capacity is 8 and the queue is full. Thread A calls `enq([|1;2;3|])` (needs 3 slots) and blocks. Thread B calls `enq([|4|])` (needs 1 slot) and blocks behind A. A dequeuer removes 1 item (1 slot free). Even though B's request fits, **A arrived first**, so neither proceeds. Only when 3+ slots are free does A's enqueue complete, then B can follow.

### Design Approach

Use a **single mutex** with **per-waiter condition variables**:

- Each blocked thread creates a waiter record with its own `Condition.t`
- Waiters are tracked in FIFO queues (one for enqueue waiters, one for dequeue waiters)
- When queue state changes, only the head waiter of each queue is signaled (if satisfiable)
- A waiter proceeds only when it is at the head AND its request can be satisfied

---

## Your Task

### Files to Complete

1. **`BatchQueue.ml`** - Batch queue implementation
   - `create` - initialize the queue
   - `enq` - blocking batch enqueue
   - `deq` - blocking batch dequeue
   - `try_enq` - non-blocking batch enqueue
   - `try_deq` - non-blocking batch dequeue
   - `notify` helper - wake eligible head waiters
   - `size` and `capacity` - query functions

2. **`test_manual.ml`** - Manual concurrent tests
   - Test sequential operations
   - Test blocking behavior (enq blocks when full, deq blocks when empty)
   - Test FIFO ordering
   - Test head-of-line blocking
   - Stress test

3. **`qcheck_lin_batch_queue.ml`** - QCheck-Lin linearizability test
   - Complete the provided skeleton following Lecture 3 examples
   - Test `try_enq`/`try_deq` (non-blocking variants)
   - Define wrapper functions for fixed batch sizes (1, 2, 3)

4. **`qcheck_stm_batch_queue.ml`** - QCheck-STM state machine test
   - Complete the TODOs in the provided skeleton
   - Implement `next_state` and `postcond`

### Provided Files

- **`BatchQueue.mli`** - Complete interface (do not modify)
- **`dune`**, **`dune-project`** - Build configuration
- **`Makefile`** - Convenience targets

---

## Part 1: Implementation (55 points)

Implement the batch queue in `BatchQueue.ml`. The type definitions and waiter
types are provided.

### Key Requirements

1. **Single mutex** protecting all queue state
2. **Per-waiter condition variables** - each blocked thread gets its own `Condition.t`
3. **FIFO waiter queues** - use OCaml's `Queue.t` to track blocked waiters
4. **Head-of-line blocking** - only the head waiter is eligible to proceed
5. **Proper validation** - reject invalid arguments with `Invalid_argument`
6. **Non-blocking try variants** - return immediately instead of blocking

### Validation Rules

- `create(capacity)`: capacity must be > 0
- `enq(q, items)`: `Array.length items` must be in [1, capacity]
- `deq(q, n)`: `n` must be in [1, capacity]
- Same rules apply to `try_enq` and `try_deq`

### Implementation Hints

- Use `Queue.peek` with physical equality (`==`) to check if a waiter is at the head
- Use `Queue.length q.buffer` to check current size
- After any enqueue or dequeue completes, call a `notify` helper that checks both waiter queue heads
- Use `Fun.protect ~finally` to ensure the mutex is always unlocked

---

## Part 2: Manual Tests (20 points)

Complete `test_manual.ml` with concurrent correctness tests.

### Required Tests

1. **Sequential basic test**: Basic enq/deq, size, capacity in a single thread
2. **Error handling test**: Invalid arguments raise `Invalid_argument`
3. **Blocking test**: deq blocks until items arrive, enq blocks until space frees
4. **FIFO test**: Single producer/consumer pair sees items in FIFO order
5. **Dequeuer head-of-line test**: deq(5) before deq(2); deq(5) must be served first
6. **Enqueuer head-of-line test**: enq(3) before enq(1); enq(1) must not jump ahead
7. **No lost items test**: No items lost or duplicated under concurrent access
8. **Batch atomicity test**: A batch enqueue is not interleaved with another batch
9. **Stress test**: Multiple producers and consumers with many operations

---

## Part 3: QCheck-Lin Test (10 points)

Complete the skeleton in `qcheck_lin_batch_queue.ml`, following Lecture 3 examples.

### Study These Examples

From Lecture 3 code (course public repository):

- `lectures/03_concurrent_objects/code/test/qcheck_lin_bounded.ml`
- `lectures/03_concurrent_objects/code/test/qcheck_lin_lockfree.ml`

### Design Note

The blocking `enq`/`deq` can hang without a matching partner, so test the
**non-blocking** `try_enq`/`try_deq` variants instead. Since the Lin DSL works
best with primitive types, define wrapper functions for fixed batch sizes:

```ocaml
let try_enq1 q x = BatchQueue.try_enq q [| x |]
let try_enq2 q x y = BatchQueue.try_enq q [| x; y |]
let try_deq1 q = BatchQueue.try_deq q 1
let try_deq2 q = BatchQueue.try_deq q 2
```

Register each wrapper as a separate operation in the `api` list.

### Lin DSL Hints

| Return type | Lin combinator |
| --- | --- |
| `bool` | `returning bool` |
| `int` | `returning int` |
| `int array option` | `returning (option (array int_small))` |

---

## Part 4: QCheck-STM Test (10 points)

Complete `qcheck_stm_batch_queue.ml` by filling in TODOs.

### Study This Example

From Lecture 3 code:

- `lectures/03_concurrent_objects/code/test/qcheck_stm_lockfree.ml`

### Your Tasks

#### 1. `next_state` - Update the model

The model state is an `int list` representing queue contents (head at front).

- `Try_enq(items)`: if items fit (`length + batch_size <= capacity`), append to list
- `Try_deq(n)`: if enough items (`length >= n`), drop first n from list
- `Size`, `Capacity`: queries don't change state

#### 2. `postcond` - Verify correctness

- `Try_enq(items)`: result should be `true` if items fit, `false` otherwise
- `Try_deq(n)`: result should be `Some(first n items)` if enough, `None` otherwise
- `Size`: should equal `List.length state`
- `Capacity`: should equal the queue capacity

---

## Building and Testing

```bash
make build          # Build everything
make test           # Run all tests
make test-manual    # Manual tests only
make test-lin       # QCheck-Lin only
make test-stm-seq   # QCheck-STM sequential
make test-stm-conc  # QCheck-STM concurrent
```

---

## Grading Rubric

| Component | Points | Description |
| --- | --- | --- |
| **Implementation** | 55 | Autograder: basic (10) + concurrent (20) + FIFO (25) |
| **Manual Tests** | 20 | Concurrent correctness tests |
| **QCheck-Lin** | 10 | Linearizability test for try_enq/try_deq |
| **QCheck-STM** | 10 | State machine test (next_state + postcond) |
| **Code Review** | 5 | Code quality |
| **Total** | 100 | |

---

## Submission

Submit the following files:

1. `BatchQueue.ml` - Your implementation
2. `test_manual.ml` - Manual tests
3. `qcheck_lin_batch_queue.ml` - QCheck-Lin test
4. `qcheck_stm_batch_queue.ml` - Completed QCheck-STM test

---

## Tips and Common Pitfalls

### Implementation Tips

1. **Always use `Fun.protect`** to ensure mutex unlock even on exceptions
2. **Check FIFO before space**: a thread must be at the waiter queue head AND have enough space/items
3. **Physical equality for head check**: use `==` (not `=`) to check `Queue.peek waiters == my_waiter`
4. **Notify after every operation**: call your notify helper after both enq and deq complete

### Testing Tips

1. **Use barriers for ordering**: `Atomic.t` counters + spin loops to control thread arrival order
2. **Sleep for timing**: small `Unix.sleepf` calls to let blocked threads settle before assertions
3. **Balance producers and consumers**: ensure total items produced = total consumed to avoid deadlocks

### Common Mistakes

- Forgetting to check `enq_waiters` emptiness in the fast path (breaks FIFO)
- Using `Condition.broadcast` instead of `Condition.signal` (works but inefficient)
- Not validating arguments before locking the mutex
- Deadlock from not unlocking mutex on exception paths
- `try_deq` creating a reservation waiter (it should return `None` immediately)

---

## Resources

### Course Materials

- Lecture 6: Monitors and Condition Variables
- Lecture 3: Concurrent Objects (QCheck-Lin, QCheck-STM)

### OCaml Documentation

- [Mutex module](https://ocaml.org/api/Mutex.html)
- [Condition module](https://ocaml.org/api/Condition.html)
- [Queue module](https://ocaml.org/api/Queue.html)
- [Domain module](https://ocaml.org/api/Domain.html)

### QCheck Documentation

- [QCheck-Lin](https://ocaml-multicore.github.io/multicoretests/0.10/qcheck-lin/)
- [QCheck-STM](https://ocaml-multicore.github.io/multicoretests/0.10/qcheck-stm/)

---

Good luck!
