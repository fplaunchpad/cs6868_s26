# Research Mini-Projects

The research mini-project is worth **16%** of the final grade and is done in
groups of **3**. The project should involve implementing a concurrent algorithm
or data structure that is **not discussed in class** but is related to the course
objectives. The implementation language is flexible — it need not be OCaml 5.

### Use of LLMs

You are expected to use LLMs (e.g., GitHub Copilot, ChatGPT) as part of your
workflow. We strongly recommend signing up for [GitHub Copilot for
Education](https://docs.github.com/en/copilot/managing-copilot/managing-copilot-as-an-individual-subscriber/managing-your-copilot-subscription/getting-free-access-to-copilot-as-a-student-teacher-or-maintainer),
which is free for students.

**However:** while an LLM may generate code, **you are responsible for every
line it produces.** You must review and understand all LLM-generated code before
submitting it. During the presentation or Q&A, an answer of *"the LLM generated
it, I don't know what it does"* will receive the lowest marks possible.

### Deliverables

Every project must produce three deliverables:

1. **Implementation** — working code for a concurrency problem not covered in
   lectures, with tests and/or evaluation demonstrating correctness and
   performance.
2. **Written report** — 5–10 pages, LaTeX (template will be shared). The report
   should cover: goals of the project, tasks undertaken, evaluation, and
   conclusions. The report **must** list the contributions of each group member
   in terms of percentages.
3. **Presentation** — 10-minute presentation + Q&A. Only one group member needs
   to present.

### Grading Rubric (out of 16 marks)

| Component | Marks | What we look for |
|---|---|---|
| Challenge of the problem undertaken | 3 | Ambition, novelty, relevance to course topics |
| Progress made towards the challenge | 5 | Working implementation, depth of evaluation, evidence of effort |
| Written report | 5 | Clarity, technical depth, proper evaluation, contribution breakdown |
| Presentation | 3 | Clear explanation, good use of time, ability to answer questions |

### Important Dates

Deadlines for topic approval, report submission, and presentations will be
announced soon.

---

## Project Ideas

Below are suggested project ideas. You are free to propose your own topic
(subject to instructor approval). The ideas below use OCaml 5 as the
implementation language, but you may adapt them to another language or propose
an entirely different project. Each idea is described using:

- **Background** — motivation and connection to course topics
- **Tasks** — concrete implementation, testing, and evaluation steps
- **Research question** — the central question your project should answer
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

### References

- RCU: <https://en.wikipedia.org/wiki/Read-copy-update>
- P. McKenney, J. Walpole, "Introducing Technology into the Linux Kernel," *Linux Symposium*, 2006
- AoMPP Chapter 8

---

## Project 7: Systematic Concurrency Testing with Dscheck

### Background

Testing concurrent data structures with random scheduling (as in QCheck-Lin) is
effective but inherently incomplete — rare interleavings may never be explored.
**Dscheck** is a model checker for OCaml 5 that systematically enumerates all
possible thread interleavings of a test, guaranteeing that if a bug exists within
the test's scope, it will be found. Dscheck operates by intercepting `Atomic`
operations and controlling the scheduler, making it a powerful complement to
property-based testing. This project applies dscheck to the concurrent data
structures studied throughout the course.

### Tasks

1. Write **dscheck tests** for at least four concurrent data structures or
   synchronisation primitives covered in class, for example:
   - Spin locks (TAS, TTAS, Backoff, ALock) from Lecture 05
   - The atomic snapshot from Assignment 2
   - Fine-grained and lock-free linked lists from Lecture 07
   - The lock-free stack or queue from Lecture 08
2. For each data structure, design minimal test scenarios (2–3 threads, small
   state) that capture the key correctness properties (mutual exclusion,
   linearizability, absence of lost updates). Document why each scenario is
   sufficient to exercise the interesting interleavings.
3. Compare **dscheck** with **QCheck-Lin**: for each data structure, report
   (a) whether dscheck finds bugs that QCheck-Lin misses (or vice versa),
   (b) the number of interleavings explored, and (c) wall-clock time to
   exhaustively check the scenario.
4. Introduce **seeded bugs** (e.g., weaken a `compare_and_set` to a plain
   store, remove a fence) and verify that dscheck reliably detects them.

### Research Question

How does systematic interleaving enumeration (dscheck) compare with randomised
linearizability testing (QCheck-Lin) in terms of bug-finding ability, test
authoring effort, and scalability to larger thread counts and state spaces?

### References

- Dscheck: <https://github.com/ocaml-multicore/dscheck>
- QCheck-Lin / QCheck-STM: <https://github.com/ocaml-multicore/multicoretests>
- AoMPP Chapters 3, 7, 9

---

## Project 8: Parking-Lot Based Mutex — When Blocking Beats Spinning

### Background

Lecture 05 studied several spin lock designs (TAS, TTAS, Backoff, ALock) that
keep waiting threads spinning on shared memory. Spinning is cheap when critical
sections are short and contention is low, but under sustained contention it
wastes CPU cycles, generates cache-coherence traffic, and starves other threads
of resources. The **parking lot** approach, popularised by WebKit and Rust's
`parking_lot` crate, takes the opposite stance: waiting threads **park**
(block via the OS scheduler) rather than spin, and are **unparked** (woken)
when the lock becomes available. A global hash table maps lock addresses to
wait queues, so the mutex itself is only one byte wide. This design has been
shown to outperform both spin locks and traditional OS mutexes in many workloads,
challenging the conventional wisdom that spinning is always faster for short
critical sections.

### Tasks

1. Implement a **parking-lot mutex** in OCaml 5. Use `Atomic` for the lock
   state and OCaml 5 domains or `Condition`/`Mutex` from the stdlib to
   implement the park/unpark mechanism. The lock word should encode at least
   two bits of state: *locked* and *has-waiters*.
2. Implement a **global hash table of wait queues** (the "parking lot") that
   maps lock addresses to FIFO wait lists. Protect each bucket with a
   short-held stdlib `Mutex` — this is the kernel of the design.
3. Verify mutual exclusion using **QCheck-Lin**: wrap a shared counter and
   check that concurrent increments are linearizable.
4. Run **TSAN** to confirm the implementation is race-free.
5. Benchmark against: (a) the spin locks from Lecture 05 (TAS, TTAS, Backoff,
   ALock), (b) the stdlib `Mutex`, and (c) if time permits, the CLH/MCS locks
   from Project 1. Measure throughput (ops/sec) and tail latency across 1–8
   threads under three contention profiles:
   - **Low contention** — short critical section, few threads
   - **High contention** — short critical section, many threads
   - **Long critical section** — simulate I/O or allocation inside the lock

### Research Question

Does a parking-lot mutex that blocks waiting threads outperform spin locks and
the OCaml stdlib `Mutex` under high contention and longer critical sections,
and at what contention level does blocking start to win over spinning?

### References

- parking_lot crate: <https://crates.io/crates/parking_lot>
- A. Matklad, "Mutexes Are Faster Than Spinlocks," 2020: <https://matklad.github.io/2020/01/04/mutexes-are-faster-than-spinlocks.html>
- AoMPP Chapter 7 (Spin Locks and Contention)
