# Research Mini-Projects

The research mini-project is worth **16%** of the final grade and is done in
groups of **3**. The project should involve: (1) implementing a concurrent
algorithm or data structure in OCaml 5, (2) verifying its correctness using
property-based testing tools (QCheck-Lin, QCheck-STM, or dscheck), and (3) a
performance evaluation with a written analysis.

Each project is described using the following framework:

- **Background** — motivation and connection to course topics
- **Tasks** — concrete implementation, testing, and evaluation steps
- **Research question** — the central question your project should answer
- **Deliverables** — what to submit
- **References** — starting points

---

## Project 1: MCS and CLH Queue Locks

### Background

The array-based queue lock (ALock) covered in Lecture 05 improves on TAS/TTAS
by giving each thread its own spin location, but wastes space proportional to
the maximum number of threads. CLH and MCS locks achieve the same local-spinning
property in O(1) space per thread using linked lists of queue nodes. They are
widely used in practice (MCS appears in the Linux kernel) and represent the
state of the art in fair, scalable mutex design.

### Tasks

1. Implement the **CLH lock** and **MCS lock** in OCaml 5, using `Atomic`
   operations throughout to comply with the OCaml memory model (Lecture 04).
2. Use `Atomic.make_contended` to prevent false sharing on queue nodes, as done
   in `ALock.ml`.
3. Verify correctness with QCheck-Lin by wrapping a shared counter and checking
   that all concurrent increment sequences are linearizable.
4. Run TSAN to confirm neither implementation has data races.
5. Benchmark all six locks (TAS, TTAS, Backoff, ALock, CLH, MCS) on the
   department machines: measure throughput (ops/sec) and **lock acquisition
   latency variance** across 1–8 threads under both low and high contention.

### Research Question

Does the FIFO ordering enforced by CLH/MCS reduce tail latency under sustained
high contention compared to the backoff lock, despite higher per-operation
overhead?

### Deliverables

- OCaml 5 source code (buildable with `dune`) with correctness tests
- Benchmark plots comparing all six locks across thread counts and contention levels
- A 4–6 page report covering algorithm description, correctness argument, benchmark analysis, and conclusions

### References

- AoMPP Chapter 7 (Spin Locks and Contention)
- J. M. Mellor-Crummey and M. L. Scott, "Algorithms for Scalable Synchronization on Shared-Memory Multiprocessors," *ACM TOCS*, 1991

---

## Project 2: Concurrent Linked Lists — From Fine-Grained Locking to Lock-Free

### Background

Lecture 07 introduces concurrent linked lists. The design space ranges from a
single coarse-grained lock all the way to entirely lock-free algorithms using
CAS. Each point in the design space trades implementation complexity for
concurrency. This project systematically explores that trade-off through
implementation, formal linearizability testing, and benchmarking.

### Tasks

1. Implement three variants of a concurrent sorted linked list (supporting
   `add`, `remove`, `contains`):
   - **Coarse-grained locking** — one lock for the whole list
   - **Fine-grained locking** — hand-over-hand (lock coupling)
   - **Lock-free** — Harris's linked list using `Atomic.compare_and_set` with
     logical deletion (marked pointers)
2. Test linearizability of all three using **QCheck-Lin**.
3. Run TSAN on the lock-free variant to check for data races.
4. Benchmark throughput under three workload mixes: read-heavy (90% `contains`),
   balanced (33/33/33), and write-heavy (90% `add`/`remove`) across 1–8 threads.

### Research Question

At what workload mix and thread count does the complexity of the lock-free
implementation pay off over fine-grained locking?

### Deliverables

- OCaml 5 source code with all three variants and QCheck-Lin test harnesses
- Benchmark plots for all three workload mixes across thread counts
- A 4–6 page report covering the algorithm designs, correctness argument,
  benchmark analysis, and lessons learned

### References

- AoMPP Chapter 9 (Linked Lists)
- T. Harris, "A Pragmatic Implementation of Non-Blocking Linked Lists," *DISC*, 2001

---

## Project 3: Seqlocks — Implementation, Race Freedom, and Comparison with Reader-Writer Locks

### Background

Lecture 06 introduced reader-writer locks (simple and FIFO variants). Seqlocks
are a complementary technique used extensively in the Linux kernel: writers never
block, and readers detect concurrent writes by checking a sequence counter before
and after their read. Seqlocks are particularly suited to read-mostly data with
infrequent small writes (e.g., system time). Implementing them correctly in OCaml
5 requires careful use of `Atomic` to satisfy the OCaml memory model (Lecture 04).

### Tasks

1. Implement a **seqlock** in OCaml 5 using `Atomic` for the sequence counter and
   `Atomic` loads/stores for the protected data. Justify why plain refs would
   introduce data races.
2. Run **TSAN** to confirm the implementation is race-free; contrast with a naive
   ref-based version that TSAN flags.
3. Write a **QCheck-STM** test that models the seqlock against a sequential
   specification and verifies correctness under concurrent readers and writers.
4. Benchmark throughput vs. the simple RW lock and FIFO RW lock from Lecture 06,
   sweeping reader/writer ratios (e.g., 1W:1R, 1W:4R, 1W:8R) across 2–8 threads.

### Research Question

Does the wait-freedom of seqlock readers translate to higher throughput in
read-dominated workloads compared to the FIFO RW lock, and at what writer
frequency does the retry overhead become a net negative?

### Deliverables

- OCaml 5 source code with the seqlock, TSAN test, and QCheck-STM harness
- Benchmark plots sweeping reader/writer ratios and thread counts
- A 4–6 page report covering correctness (memory model argument), TSAN results,
  benchmark analysis, and conclusions

### References

- Seqlock: <https://en.wikipedia.org/wiki/Seqlock>
- OCaml Memory Model: <https://ocaml.org/manual/5.4/memorymodel.html>
- AoMPP Chapter 8 (Monitors and Blocking Synchronization)

---

## Project 4: Flat Combining — Reducing Contention via Delegation

### Background

High-contention locks, even with backoff, suffer from cache coherence storms as
many threads race on the same memory locations. Flat combining (Hendler et al.,
2010) takes a different approach: one elected "combiner" thread executes
operations on behalf of all waiting threads in a single critical section, amortising synchronisation cost and improving cache locality. It is applicable on top of any sequential data structure.

### Tasks

1. Implement a **flat combining wrapper** in OCaml 5 that can wrap any sequential
   data structure (use a queue or stack as the target). The wrapper should use a
   publication list where threads post their operations, and the combiner
   collects and executes them.
2. Verify correctness using **QCheck-Lin** — the combined executions must still
   be linearizable.
3. Benchmark a flat-combined queue against (a) a mutex-protected queue and (b)
   the blocking queue from Lecture 06, under varying thread counts (2–8) and
   operation-mix ratios (enqueue-heavy, dequeue-heavy, balanced).
4. Measure **combining batch size** as a function of thread count to understand
   the amortisation benefit.

### Research Question

At what thread count does flat combining begin to outperform a simple mutex, and
how does the benefit scale with contention?

### Deliverables

- OCaml 5 source code with the flat-combining wrapper and QCheck-Lin tests
- Benchmark plots (throughput vs. threads, and batch size vs. threads)
- A 4–6 page report covering the algorithm design, correctness argument,
  benchmark analysis, and practical trade-offs

### References

- D. Hendler, I. Incze, N. Shavit, M. Tzafrir, "Flat Combining and the Synchronization-Parallelism Tradeoff," *SPAA*, 2010
- AoMPP Chapter 7

---

## Project 5: Multi-Word Compare-and-Swap (MCAS) in OCaml 5

### Background

OCaml 5 provides only single-word `Atomic.compare_and_set`. Many lock-free
algorithms require atomically updating multiple independent memory locations
(MCAS). Software MCAS can be built on top of single-word CAS by encoding
descriptor objects. This project implements MCAS and applies it to build a
simpler lock-free data structure, connecting back to the atomic snapshot object
from Assignment 2.

### Tasks

1. Implement the **Harris-Fraser-Pratt MCAS** algorithm in OCaml 5. The key
   challenge is handling descriptor objects and helping other threads complete
   in-progress MCAS operations.
2. Use MCAS to implement a **lock-free atomic snapshot** and compare its
   simplicity with the double-collect algorithm from Assignment 2.
3. Verify linearizability of both MCAS itself and the snapshot using
   **QCheck-Lin** or **dscheck**.
4. Benchmark MCAS-based snapshot `update`/`scan` throughput against the
   Assignment 2 implementation across 2–8 threads under varying update/scan ratios.

### Research Question

Does MCAS provide enough expressive power to meaningfully simplify the
implementation of atomic snapshot, and what is the performance cost of the
software MCAS layer?

### Deliverables

- OCaml 5 source code with MCAS and the MCAS-based snapshot, plus test harnesses
- Benchmark plots comparing MCAS-snapshot vs. double-collect snapshot
- A 4–6 page report covering the MCAS algorithm, its use in snapshot,
  correctness argument, and performance analysis

### References

- T. Harris, K. Fraser, I. Pratt, "A Practical Multi-Word Compare-and-Swap Operation," *DISC*, 2002; also <https://arxiv.org/abs/2008.02527>
- AoMPP Chapter 3 (Concurrent Objects), Assignment 2

---

## Project 6: User-Space RCU (Read-Copy-Update) in OCaml 5

### Background

Read-Copy-Update (RCU) is a synchronisation mechanism used pervasively in the
Linux kernel. It allows read operations to proceed with **zero synchronisation
overhead** while writers atomically publish new versions of data and reclaim old
versions after a "grace period" (once all current readers have finished). RCU is
the canonical solution for read-dominated concurrent data structures. Implementing
it in user space requires careful reasoning about memory models (Lecture 04) and
epoch-based memory reclamation.

### Tasks

1. Implement a basic **user-space RCU** in OCaml 5: readers call
   `rcu_read_lock`/`rcu_read_unlock` (which must be fast — ideally just an
   atomic increment/decrement of an epoch counter), and writers call
   `synchronize_rcu` to wait for a grace period before freeing old data.
2. Apply your RCU to a **read-mostly linked list** (or dictionary): readers
   traverse without any lock, writers copy-modify-swap the affected node.
3. Verify correctness with **QCheck-STM** against a sequential model.
4. Benchmark read throughput vs. the FIFO RW lock (Lecture 06) and the seqlock
   (Project 3) under read-heavy workloads (1W:7R, 0W:8R) across 2–8 threads.

### Research Question

Can domain-based epoch tracking in OCaml 5 provide a practical grace period
mechanism for user-space RCU, and how does RCU read throughput compare with
reader-writer locks and seqlocks at high reader concurrency?

### Deliverables

- OCaml 5 source code with the RCU implementation, an RCU-based data structure,
  and QCheck-STM tests
- Benchmark plots for read throughput across varying reader/writer ratios
- A 4–6 page report covering the RCU design, grace period mechanism, correctness
  argument, benchmark analysis, and any limitations encountered

### References

- RCU: <https://en.wikipedia.org/wiki/Read-copy-update>
- P. McKenney, J. Walpole, "Introducing Technology into the Linux Kernel," *Linux Symposium*, 2006
- AoMPP Chapter 8
