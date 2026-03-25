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

Code and report must be submitted as a single GitHub repository. The report
must be written in LaTeX, Markdown, or another open, machine-readable format.

### Grading Rubric (out of 16 marks)

| Component | Marks | What we look for |
|---|---|---|
| Challenge of the problem undertaken | 3 | Ambition, novelty, relevance to course topics. Each project below has a difficulty rating (★ to ★★★★★). **Higher-difficulty projects receive higher marks in this component even if completion is partial.** |
| Progress made towards the challenge | 5 | Working implementation, depth of evaluation, evidence of effort |
| Written report | 5 | Clarity, technical depth, proper evaluation, contribution breakdown |
| Presentation | 3 | Clear explanation, good use of time, ability to answer questions |

### Important Dates

| Task | Date |
|---|---|
| Project topic approval | 30/03/2026 |
| Report & code submission | 26/04/2026 |
| Presentation | Week of 27/04/2026 |

Fill in your group members and chosen project topic in the
[sign-up sheet](https://docs.google.com/spreadsheets/d/1kINa3ipNcyxAqh1wXC9_65xeZg25QFDirSUEqUU3IyA/edit?gid=0#gid=0)
by the topic approval deadline.

---

## Project Ideas

1. [MCS and CLH Queue Locks](#project-1-mcs-and-clh-queue-locks)
2. [Concurrent Linked Lists — From Fine-Grained Locking to Lock-Free](#project-2-concurrent-linked-lists--from-fine-grained-locking-to-lock-free)
3. [Seqlocks — Implementation, Race Freedom, and Comparison with Reader-Writer Locks](#project-3-seqlocks--implementation-race-freedom-and-comparison-with-reader-writer-locks)
4. [Flat Combining — Reducing Contention via Delegation](#project-4-flat-combining--reducing-contention-via-delegation)
5. [Multi-Word Compare-and-Swap (MCAS) in OCaml 5](#project-5-multi-word-compare-and-swap-mcas-in-ocaml-5)
6. [User-Space RCU (Read-Copy-Update) in OCaml 5](#project-6-user-space-rcu-read-copy-update-in-ocaml-5)
7. [Systematic Concurrency Testing with Dscheck](#project-7-systematic-concurrency-testing-with-dscheck)
8. [Parking-Lot Based Mutex — When Blocking Beats Spinning](#project-8-parking-lot-based-mutex--when-blocking-beats-spinning)
9. [Work-Stealing Deque and a Parallel Task Scheduler](#project-9-work-stealing-deque-and-a-parallel-task-scheduler)
10. [Concurrent Hash Map — Striped Locking vs. Split-Ordered Lists](#project-10-concurrent-hash-map--striped-locking-vs-split-ordered-lists)
11. [Lock-Free Skip List](#project-11-lock-free-skip-list)
12. [Bounded Lock-Free Queues — From SPSC to MPMC](#project-12-bounded-lock-free-queues--from-spsc-to-mpmc)
13. [Concurrent Priority Queue — Heap vs. Skip List](#project-13-concurrent-priority-queue--heap-vs-skip-list)
14. [Software Transactional Memory (TL2)](#project-14-software-transactional-memory-tl2)
15. [Herlihy's Universal Construction](#project-15-herlihys-universal-construction)
16. [Concurrent Union-Find and Parallel Graph Connectivity](#project-16-concurrent-union-find-and-parallel-graph-connectivity)
17. [Barrier Implementations for Bulk-Synchronous Parallelism](#project-17-barrier-implementations-for-bulk-synchronous-parallelism)
18. [Lock-Free Binary Search Tree](#project-18-lock-free-binary-search-tree)
19. [Software Combining Tree for Scalable Shared Counting](#project-19-software-combining-tree-for-scalable-shared-counting)
20. [Counting Networks and Diffracting Trees](#project-20-counting-networks-and-diffracting-trees)
21. [Parallel Sorting — Sorting Networks and Sample Sort](#project-21-parallel-sorting--sorting-networks-and-sample-sort)
22. [Memory Reclamation — Hazard Pointers and Epoch-Based Reclamation](#project-22-memory-reclamation--hazard-pointers-and-epoch-based-reclamation)
23. [Synchronous Dual Queue](#project-23-synchronous-dual-queue)
24. [Elimination-Based Concurrent Data Structures Beyond Stacks](#project-24-elimination-based-concurrent-data-structures-beyond-stacks)

Below are suggested project ideas. You are free to propose your own topic
(subject to instructor approval). If you are presenting a new project topic,
make a PR to this file. The ideas below use OCaml 5 as the
implementation language, but you may adapt them to another language or propose
an entirely different project. Each idea is described using:

- **Background** — motivation and connection to course topics
- **Tasks** — concrete implementation, testing, and evaluation steps
- **Research question** — the central question your project should answer
- **References** — starting points

---

## Project 1: MCS and CLH Queue Locks

**Difficulty: ★★☆☆☆** — Well-documented algorithms; mainly pointer manipulation with CAS. Closest to lecture content (Lecture 05).

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

**Difficulty: ★★★☆☆** — Harris's lock-free list with marked pointers is tricky, but the algorithm is covered in Lecture 07.

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

**Difficulty: ★★☆☆☆** — Simple algorithm; the main challenge is memory-model reasoning and TSAN analysis.

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

**Difficulty: ★★★☆☆** — The combiner election and publication list logic introduce a novel paradigm not seen in lectures.

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

**Difficulty: ★★★★☆** — Descriptor-based helping is conceptually deep; correct MCAS is substantially harder than single-word CAS algorithms.

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

- T. Harris, K. Fraser, I. Pratt, "A Practical Multi-Word Compare-and-Swap Operation," *DISC*, 2002
- R. Guerraoui, A. Kogan, V. J. Marathe, I. Zablotchi, "Efficient Multi-word Compare and Swap," *DISC*, 2020: <https://arxiv.org/abs/2008.02527>
- AoMPP Chapter 3 (Concurrent Objects), Assignment 2

---

## Project 6: User-Space RCU (Read-Copy-Update) in OCaml 5

**Difficulty: ★★★★☆** — Grace-period reasoning and epoch tracking are subtle; requires deep memory-model understanding.

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

**Difficulty: ★★☆☆☆** — Breadth over depth; requires understanding many data structures but no new algorithmic invention.

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

**Difficulty: ★★★☆☆** — Combines OS-level blocking with lock-state encoding; the global parking-lot hash table adds systems complexity.

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

---

## Project 9: Work-Stealing Deque and a Parallel Task Scheduler

**Difficulty: ★★★★☆** — The Chase-Lev deque's pop-vs-steal race is subtle, and building a working scheduler on top adds significant engineering.

### Background

Work stealing is the dominant scheduling strategy in modern parallel runtimes
(Cilk, Intel TBB, Go, Tokio, Java ForkJoinPool). Each worker thread maintains a
**double-ended queue (deque)**: it pushes and pops tasks from its own end (LIFO,
for cache locality), while idle workers **steal** from the opposite end (FIFO,
for load balancing) using CAS. The Chase-Lev deque (2005) is the canonical
lock-free implementation — it uses a growable circular array with only two atomic
indices and requires just a single CAS for the steal path. Despite its simplicity,
the algorithm is subtle: the interaction between the owner's pop and a thief's
steal on the last element requires careful coordination to avoid lost tasks.

### Tasks

1. Implement the **Chase-Lev work-stealing deque** in OCaml 5 using `Atomic`
   operations. The deque must support `push` (owner only), `pop` (owner only),
   and `steal` (called by any other domain). Implement the **growable circular
   array** — the deque must dynamically resize when full rather than failing.
2. Build a **parallel task scheduler** on top of the deque: spawn `n` OCaml 5
   domains, each running a work loop that executes local tasks and steals from
   random victims when idle. Support a `fork`/`join` API that recursively
   decomposes a problem (e.g., parallel mergesort, parallel map over an array,
   or Fibonacci as a stress test).
3. Verify the deque's correctness using **QCheck-Lin** and **QCheck-STM**:
   model the deque as a sequential double-ended queue and test that concurrent
   push/pop/steal sequences are linearizable (QCheck-Lin) and conform to the
   sequential specification (QCheck-STM).
4. Run **TSAN** to confirm the deque and scheduler are race-free.
5. Benchmark the scheduler on two parallel workloads (e.g., parallel mergesort
   and a recursive divide-and-conquer computation) across 1–8 domains. Measure
   **speedup**, **steal rate**, and **task throughput**. Compare against a naive
   shared-queue scheduler protected by a single mutex.
6. Investigate the impact of **steal policy** (random victim vs. round-robin)
   and **task granularity** (varying the threshold at which recursion stops and
   sequential execution takes over) on performance.

### Research Question

How effectively does work stealing balance load across OCaml 5 domains for
irregular parallel workloads, and what is the relationship between task
granularity, steal frequency, and overall speedup?

### References

- D. Chase, Y. Lev, "Dynamic Circular Work-Stealing Deque," *SPAA*, 2005
- N. S. Arora, R. D. Blumofe, C. G. Plaxton, "Thread Scheduling for Multiprogrammed Multiprocessors," *Theory of Computing Systems*, 2001
- Crossbeam's deque implementation (Rust): <https://docs.rs/crossbeam-deque/latest/crossbeam_deque/>

---

## Project 10: Concurrent Hash Map — Striped Locking vs. Split-Ordered Lists

**Difficulty: ★★★★☆** — Striped locking is moderate, but lock-free split-ordered lists with incremental resizing are very challenging.

### Background

Hash maps are among the most widely used data structures, and making them
concurrent is a core challenge in practice. Two major approaches exist:
**striped locking**, where the bucket array is partitioned into lock stripes
(each stripe is a mutex protecting a subset of buckets), and **split-ordered
lists** (Shalev & Shavit, 2006), a lock-free design that represents the hash
table as a single sorted linked list with sentinel nodes, enabling **lock-free
resizing** without rehashing. The key insight of split-ordered lists is to store
keys in bit-reversed order so that bucket splits never require moving items. Both
approaches connect directly to the concurrent linked list techniques from
Lecture 07 and the locking strategies from Lectures 05–06.

### Tasks

1. Implement a **striped concurrent hash map** in OCaml 5: use an array of
   `Mutex`-protected buckets with a configurable stripe count. Support `insert`,
   `remove`, and `find`. Implement **dynamic resizing**: when the load factor
   exceeds a threshold, acquire all stripes, allocate a new bucket array, and
   rehash.
2. Implement a **lock-free hash map using split-ordered lists** in OCaml 5. The
   table should consist of a single lock-free linked list (using
   `Atomic.compare_and_set` with logical deletion as in Lecture 07) plus an
   expandable array of sentinel pointers. Implement **incremental resizing** by
   lazily initialising new sentinel nodes as the table grows.
3. Verify correctness of both implementations using **QCheck-Lin** and
   **QCheck-STM**: model the hash map as a sequential `Hashtbl` and test
   concurrent `insert`/`remove`/`find` sequences for linearizability
   (QCheck-Lin) and sequential specification conformance (QCheck-STM).
4. Run **TSAN** on both implementations.
5. Benchmark throughput under three workload profiles: read-heavy (90% `find`),
   write-heavy (90% `insert`/`remove`), and mixed (50/25/25), across 1–8
   threads. Also measure throughput **during active resizing** to evaluate how
   each design handles growth under load.
6. Measure and compare **memory overhead** of the two approaches: the striped
   design wastes space on locks per stripe, while split-ordered lists add
   sentinel nodes.

### Research Question

Does the lock-free split-ordered list design provide meaningful throughput
advantages over striped locking under read-heavy workloads, and how do the two
approaches compare during concurrent resizing?

### References

- O. Shalev, N. Shavit, "Split-Ordered Lists: Lock-Free Extensible Hash Tables," *JACM*, 2006
- AoMPP Chapter 13 (Concurrent Hashing)
- Java `ConcurrentHashMap` source code (striped locking reference)

---

## Project 11: Lock-Free Skip List

**Difficulty: ★★★★☆** — Multi-level CAS with marked pointers on each level; many subtle edge cases during concurrent deletion.

### Background

Skip lists are a probabilistic alternative to balanced binary search trees:
they provide expected O(log n) search, insertion, and deletion using multiple
levels of linked lists with random heights, but without the complex rotations
required by red-black or AVL trees. This simplicity makes them well-suited to
concurrent settings. The lock-free skip list, described by Fraser (2004) and
Herlihy et al. (2006), extends Harris's linked-list technique (Lecture 07) to
multiple levels: nodes are logically deleted by marking pointers at each level,
then physically unlinked by subsequent traversals. Lock-free skip lists are used
in practice as concurrent sorted maps (e.g., Java's `ConcurrentSkipListMap`,
Redis sorted sets, LevelDB's memtable).

### Tasks

1. Implement a **lock-free concurrent skip list** in OCaml 5 supporting `add`,
   `remove`, and `contains` on integer keys. Use `Atomic.compare_and_set` with
   marked pointers for logical deletion at each level, following the approach
   from Lecture 07's Harris list. Choose a maximum level (e.g., 20) and use
   randomised promotion.
2. Implement a **fine-grained locking skip list** as a baseline: lock nodes
   hand-over-hand at each level during insertion and deletion (extending the
   hand-over-hand technique from Lecture 07 to multiple levels).
3. Verify correctness of both implementations using **QCheck-Lin** and
   **QCheck-STM**: test linearizability (QCheck-Lin) and conformance to a
   sequential sorted-set specification (QCheck-STM).
4. Run **TSAN** on the lock-free variant.
5. Benchmark throughput of both skip lists and the lock-free hash map (if
   available from Project 10, or a mutex-protected `Hashtbl`) under read-heavy
   (90% `contains`), balanced (33/33/33), and write-heavy (90% `add`/`remove`)
   workloads across 1–8 threads.
6. Measure the **distribution of traversal lengths** (number of nodes visited
   per operation) under concurrent modification to evaluate whether contention
   causes excessive retries in the lock-free variant.

### Research Question

How does the lock-free skip list's throughput scale compared to a fine-grained
locking skip list across different workload mixes, and does the multi-level
structure amplify or mitigate the retry overhead of lock-free operations compared
to a single-level Harris list?

### References

- K. Fraser, "Practical Lock-Freedom," *PhD thesis, University of Cambridge*, 2004, Chapter 4
- M. Herlihy, Y. Lev, V. Luchangco, N. Shavit, "A Provably Correct Scalable Concurrent Skip List," *OPODIS*, 2006
- AoMPP Chapter 14 (Skip Lists and Balanced Search)

---

## Project 12: Bounded Lock-Free Queues — From SPSC to MPMC

**Difficulty: ★★★☆☆** — SPSC is straightforward; the MPMC ring buffer with sequence numbers is moderately challenging.

### Background

The lock-free unbounded queues studied in Lecture 08 (Michael-Scott queue)
allocate a new node per enqueue, which adds GC pressure and cache misses. In
practice, many high-performance systems use **bounded queues** backed by
pre-allocated ring buffers. The design space ranges from the simplest case —
a **single-producer/single-consumer (SPSC)** queue requiring no CAS at all
(just two atomic indices, as observed by Lamport, 1983) — to the much harder
**multi-producer/multi-consumer (MPMC)** case, where both ends are contended.
The LMAX Disruptor, used in financial trading systems processing millions of
messages per second, popularised ring-buffer-based concurrent queues and
introduced techniques like sequence padding to avoid false sharing. This project
systematically builds up from SPSC to MPMC, comparing the trade-offs at each
point.

### Tasks

1. Implement a **bounded SPSC queue** in OCaml 5 using a fixed-size array and
   two `Atomic` indices (head and tail). No CAS should be needed — only atomic
   loads and stores. Use `Atomic.make_contended` for the indices to prevent
   false sharing.
2. Implement a **bounded MPMC queue** in OCaml 5. Use a ring buffer where each
   slot contains an `Atomic` sequence number. Producers and consumers CAS their
   respective indices to claim a slot, then write/read the slot and update its
   sequence number to signal completion. This is the approach used by Dmitry
   Vyukov's bounded MPMC queue.
3. Implement a **bounded MPSC (multi-producer/single-consumer)** variant as an
   intermediate point: multiple producers CAS the tail, but only one consumer
   reads the head (no CAS needed on the consumer side).
4. Verify correctness of all three using **QCheck-Lin** and **QCheck-STM**:
   model as a sequential bounded queue with `try_enqueue`/`try_dequeue`
   returning `Some`/`None`. Use QCheck-Lin for linearizability and QCheck-STM
   to test against the sequential specification (including full/empty
   boundary behaviour).
5. Run **TSAN** on all three implementations.
6. Benchmark throughput (ops/sec) across 1–8 threads under: (a) 1P:1C, (b)
   nP:1C, (c) 1P:nC, and (d) nP:nC configurations. Compare against the
   Michael-Scott lock-free queue from Lecture 08 and a mutex-protected
   `Queue.t`. Measure the impact of **batch size** (enqueue/dequeue k items
   per operation) on throughput.
7. Investigate **false sharing**: benchmark with and without contended padding
   on the head/tail indices and slot sequence numbers.

### Research Question

How much throughput does a pre-allocated ring buffer gain over the
allocation-heavy Michael-Scott queue across different producer/consumer
configurations, and where in the SPSC → MPSC → MPMC design space does the
complexity-performance trade-off shift most dramatically?

### References

- L. Lamport, "Specifying Concurrent Program Modules," *ACM TOPLAS*, 1983 (SPSC ring buffer)
- D. Vyukov, "Bounded MPMC Queue," 2010: <https://www.1024cores.net/home/lock-free-algorithms/queues/bounded-mpmc-queue>
- LMAX Disruptor: <https://lmax-exchange.github.io/disruptor/>
- AoMPP Chapter 10 (Queues), Lecture 08

---

## Project 13: Concurrent Priority Queue — Heap vs. Skip List

**Difficulty: ★★★★☆** — Maintaining the heap invariant under concurrency is very tricky; the skip-list variant also requires careful deleteMin coordination.

### Background

Priority queues are fundamental to scheduling, simulation, and graph algorithms.
Making them concurrent is challenging because both insertion and deletion-of-min
modify the "hot" top of the structure. Two main approaches exist: **concurrent
heaps**, where `deleteMin` and `insert` contend on the root and require careful
locking or lock-free protocols to maintain the heap invariant, and **skip-list-
based priority queues**, where the minimum is always at the head of the bottom
level, so `deleteMin` is a lock-free linked-list deletion (Lecture 07) while
`insert` distributes contention across multiple levels. Lotan and Shavit (2000)
and Linden and Jonsson (2013) showed that skip-list-based designs significantly
outperform heap-based ones under high contention.

### Tasks

1. Implement a **skip-list-based concurrent priority queue** in OCaml 5
   supporting `insert` and `deleteMin`. Use `Atomic.compare_and_set` with
   logical deletion (marked pointers) for the `deleteMin` path, following the
   Lotan-Shavit or Linden-Jonsson design. The key challenge is that multiple
   threads performing `deleteMin` must coordinate to ensure each minimum element
   is returned to exactly one thread.
2. Implement a **lock-based concurrent heap** as a baseline: use fine-grained
   locking where each heap node has its own lock, and `insert`/`deleteMin`
   acquire locks top-down along the path they traverse. Implement the
   Hunt-Michael-Parthasarathy-Scott approach where `insert` proceeds bottom-up
   and `deleteMin` proceeds top-down.
3. Verify correctness of both using **QCheck-Lin** and **QCheck-STM**: model
   as a sequential priority queue (e.g., a sorted list or `Set`) and test
   concurrent `insert`/`deleteMin` sequences for linearizability (QCheck-Lin)
   and sequential specification conformance (QCheck-STM).
4. Run **TSAN** on both implementations.
5. Benchmark throughput across 1–8 threads under: (a) balanced (50% `insert`,
   50% `deleteMin`), (b) insert-heavy (80/20), and (c) delete-heavy (20/80)
   workloads. Also measure throughput under **skewed key distributions** (e.g.,
   all threads inserting keys near the current minimum) to stress the contention
   on `deleteMin`.
6. Apply one implementation to a **parallel discrete-event simulation** or
   **parallel Dijkstra** to demonstrate a realistic use case.

### Research Question

Does the skip-list-based priority queue's ability to distribute contention across
levels provide a decisive throughput advantage over the heap-based design, and
how does key distribution skew affect the relative performance?

### References

- I. Lotan, N. Shavit, "Skiplist-Based Concurrent Priority Queues," *IPDPS*, 2000
- J. Linden, B. Jonsson, "A Skiplist-Based Concurrent Priority Queue with Minimal Memory Contention," *OPODIS*, 2013
- AoMPP Chapter 15 (Priority Queues)

---

## Project 14: Software Transactional Memory (TL2)

**Difficulty: ★★★★★** — Building a full STM runtime (version clock, read/write-set tracking, validation, retry) is a significant systems project.

### Background

Lock-free programming is powerful but error-prone: every new data structure
requires a bespoke algorithm with subtle CAS loops and retry logic. **Software
Transactional Memory (STM)** offers a radically different model: programmers
wrap shared-memory operations in transactions that appear to execute atomically.
The runtime speculatively executes transactions, tracks read and write sets, and
validates at commit time — aborting and retrying on conflict. TL2 (Dice, Shalev,
Shavit, 2006) is the canonical lock-based STM design: it uses a global version
clock and per-location versioned locks to achieve serialisability with low
overhead. While STM has not displaced hand-tuned lock-free code in practice, the
tension between **programmer productivity** and **runtime overhead** remains one
of the central debates in concurrent programming (AoMPP Ch. 18).

### Tasks

1. Implement a **TL2-style STM runtime** in OCaml 5. The runtime should support:
   - `TVar.make`, `TVar.read`, `TVar.write` — transactional variables with
     versioned locks (use `Atomic` for the lock word encoding version + locked
     bit)
   - `atomically : (unit -> 'a) -> 'a` — execute a transaction, buffering
     writes in a thread-local write set, validating the read set at commit time,
     and retrying on abort
   - A **global version clock** (atomic counter) incremented at each commit
2. Using your STM, implement a **concurrent linked list** (sorted set with
   `add`, `remove`, `contains`) where each operation runs inside a transaction.
   Compare the code complexity against the hand-crafted fine-grained locking
   and lock-free versions from Lecture 07.
3. Implement a **concurrent bank account transfer** (move funds between two
   accounts atomically) to demonstrate composability — the key advantage of STM
   over locks.
4. Verify correctness using **QCheck-Lin** and **QCheck-STM**: test that
   concurrent transactional operations on the linked list are linearizable.
5. Run **TSAN** to confirm the STM runtime is race-free.
6. Benchmark throughput of the STM-based linked list against (a) coarse-grained
   locking, (b) fine-grained locking, and (c) the lock-free Harris list from
   Lecture 07, across 1–8 threads under read-heavy, balanced, and write-heavy
   workloads.
7. Measure **abort rate** and **read-set validation cost** as a function of
   thread count and transaction size to understand the overhead profile.

### Research Question

How much throughput does TL2-style STM sacrifice compared to hand-crafted
lock-free and fine-grained locking implementations, and does the dramatic
simplification in programming effort justify the cost?

### References

- D. Dice, O. Shalev, N. Shavit, "Transactional Locking II," *DISC*, 2006
- AoMPP Chapter 18 (Transactional Memory)
- N. Shavit, D. Touitou, "Software Transactional Memory," *PODC*, 1995

---

## Project 15: Herlihy's Universal Construction

**Difficulty: ★★★★☆** — The lock-free version is moderate; the wait-free variant with helping is conceptually demanding.

### Background

Herlihy's universality result (1991) is one of the deepest theorems in the
course: **any sequential object can be made linearizable and lock-free (or even
wait-free) given only consensus objects.** The construction works by maintaining
a linked list of applied operations (a "log"); to apply an operation, a thread
creates a new log node, uses consensus to append it, then replays the log to
compute the result. The lock-free version uses CAS to resolve contention on the
log tail, while the wait-free version adds a helping mechanism where fast threads
complete operations on behalf of slow ones. This project bridges the gap between
the theoretical consensus hierarchy (Lecture 03) and practical lock-free design.

### Tasks

1. Implement the **lock-free universal construction** in OCaml 5: a generic
   wrapper that takes a sequential object (represented as a pure function
   `state -> op -> state * result`) and produces a linearizable concurrent
   object. Use a linked list of operation nodes and `Atomic.compare_and_set`
   on the tail pointer.
2. Implement the **wait-free universal construction** with helping: each thread
   has an announce array entry; before applying its own operation, a thread
   checks whether other threads have pending operations and helps complete
   them first.
3. Apply both constructions to at least three sequential data structures:
   a **stack**, a **queue**, and a **sorted set**. Compare the resulting code
   against purpose-built concurrent implementations from Lectures 07–08.
4. Verify linearizability of all universally-constructed objects using
   **QCheck-Lin** and **QCheck-STM**.
5. Run **TSAN** on both constructions.
6. Benchmark throughput of the universally-constructed stack and queue against
   (a) the lock-free Treiber stack, (b) the Michael-Scott queue from Lecture 08,
   and (c) mutex-protected sequential versions, across 1–8 threads.
7. Measure the **cost of helping** in the wait-free version: track how often
   threads help others vs. execute their own operations, and quantify the
   throughput penalty of wait-freedom over lock-freedom.

### Research Question

What is the practical performance cost of generality — how much throughput do
the universal constructions sacrifice compared to purpose-built lock-free data
structures, and does the wait-free variant's helping mechanism introduce
prohibitive overhead?

### References

- M. Herlihy, "Wait-Free Synchronization," *ACM TOPLAS*, 1991
- AoMPP Chapter 6 (Universality of Consensus)

---

## Project 16: Concurrent Union-Find and Parallel Graph Connectivity

**Difficulty: ★★★☆☆** — CAS on parent pointers is straightforward; the subtlety is interference between path compression and concurrent union.

### Background

Union-Find (disjoint set) is a fundamental data structure for maintaining
partitions under `union` and `find` operations. The sequential version with
path compression and union-by-rank achieves near-constant amortised time per
operation. Jayanti and Tarjan (2016, 2021) showed how to make union-find
concurrent using CAS, preserving near-optimal work while allowing multiple
threads to perform `union` and `find` concurrently. The primary application is
**parallel graph connectivity**: given a large graph, determine connected
components by having multiple threads concurrently union the endpoints of edges.
This project implements concurrent union-find and applies it to a real parallel
graph problem.

### Tasks

1. Implement a **concurrent union-find** in OCaml 5 using `Atomic` operations.
   Support `find` with **path compression** (use CAS to update parent pointers)
   and `union` with **union-by-rank** (use CAS to update the root's rank and
   parent). Handle the subtlety that concurrent path compression and union can
   interfere — follow the Jayanti-Tarjan approach where `find` helps concurrent
   `union` operations.
2. Implement a **lock-based union-find** as a baseline: protect the entire
   structure with a single `Mutex`, or use fine-grained locking where each node
   has its own lock (acquired in a canonical order to avoid deadlock).
3. Apply both implementations to **parallel graph connectivity**: given an edge
   list, partition the edges across `n` domains, each domain unions the
   endpoints of its edges concurrently. Generate random graphs (Erdős–Rényi
   model) of varying sizes and densities.
4. Verify correctness using **QCheck-Lin** and **QCheck-STM**: model as a
   sequential union-find and test that concurrent `union`/`find` sequences
   produce correct partitions.
5. Run **TSAN** on the lock-free implementation.
6. Benchmark parallel connectivity on graphs with 10⁵–10⁶ nodes across 1–8
   threads. Measure **speedup**, **CAS failure rate** (retries due to
   contention on popular roots), and compare against the lock-based baseline.
7. Investigate how graph structure affects contention: compare **sparse random
   graphs** (low contention — few shared components) against **dense graphs**
   and **star graphs** (high contention — many edges share a hub node).

### Research Question

How effectively does CAS-based concurrent union-find parallelise graph
connectivity, and how does graph structure (density, degree distribution) affect
CAS contention and speedup?

### References

- S. V. Jayanti, R. E. Tarjan, "A Randomized Concurrent Algorithm for Disjoint Set Union," *PODC*, 2016
- S. V. Jayanti, R. E. Tarjan, "Concurrent Disjoint Set Union," *Distributed Computing*, 2021
- R. E. Tarjan, "Efficiency of a Good But Not Linear Set Union Algorithm," *JACM*, 1975

---

## Project 17: Barrier Implementations for Bulk-Synchronous Parallelism

**Difficulty: ★★☆☆☆** — Well-documented algorithms with clear structure; the iterative application adds modest engineering effort.

### Background

Barriers are synchronisation primitives where a group of threads must all arrive
before any can proceed to the next phase. They are fundamental to
**bulk-synchronous parallelism** — iterative computations where threads compute
locally, synchronise at a barrier, then exchange data and repeat. AoMPP
Chapter 17 describes several barrier designs with different scalability
properties: the **sense-reversing barrier** (simple, O(n) contention on a
shared counter), the **combining tree barrier** (O(log n) contention, tree of
2-thread barriers), and the **dissemination barrier** (O(n log n) total work
but only O(log n) rounds with no single contention point). Unlike the data-
structure-focused projects, barriers are about **coordination patterns** — they
test a fundamentally different aspect of concurrent programming.

### Tasks

1. Implement three barrier types in OCaml 5:
   - **Sense-reversing barrier** — a shared `Atomic` counter and a sense flag;
     the last thread to arrive flips the sense and wakes everyone.
   - **Combining tree barrier** — build a binary tree of 2-thread barriers;
     threads pair up at leaves, winners propagate up, the root thread signals
     completion back down.
   - **Dissemination barrier** — in each of O(log n) rounds, thread `i` signals
     thread `(i + 2^round) mod n` and waits for a signal from thread
     `(i - 2^round) mod n`. No single bottleneck.
2. Verify correctness: write a test where each thread increments a shared
   counter between barrier phases; after each phase, all threads must observe
   the same counter value. Use **QCheck-STM** to model the barrier as a
   sequential phase counter.
3. Run **TSAN** on all three implementations.
4. Apply the barriers to a **parallel iterative computation**: implement
   **parallel Jacobi relaxation** (or Conway's Game of Life) where threads
   update their portion of a grid, barrier-synchronise, then read neighbours'
   updated values. Run for a fixed number of iterations.
5. Benchmark **barrier latency** (time from first arrival to last departure)
   and **total computation time** for the iterative application across 2–8
   threads. Vary the **computation-to-synchronisation ratio** by changing the
   grid size (large grid = more work per phase, less relative barrier cost).
6. Compare barrier overhead with simply using `Mutex`/`Condition` to implement
   a barrier (the naive approach).

### Research Question

How does barrier design (sense-reversing vs. combining tree vs. dissemination)
affect synchronisation latency and end-to-end performance in iterative parallel
computations, and at what thread count does the O(n) contention of the simple
barrier become a bottleneck?

### References

- AoMPP Chapter 17 (Barriers)
- J. M. Mellor-Crummey, M. L. Scott, "Algorithms for Scalable Synchronization on Shared-Memory Multiprocessors," *ACM TOCS*, 1991 (includes barrier algorithms)
- L. G. Valiant, "A Bridging Model for Parallel Computation," *CACM*, 1990 (BSP model)

---

## Project 18: Lock-Free Binary Search Tree

**Difficulty: ★★★★★** — Two-step deletion with edge marking, grandparent CAS, and concurrent helping make this among the hardest lock-free data structures.

### Background

The project list covers concurrent linked lists (Project 2), skip lists
(Project 11), and hash maps (Project 10), but no **tree-based** data structures.
Balanced BSTs are harder to make lock-free than lists because modifications can
require multiple pointer updates (rotations, rebalancing) that are difficult to
perform atomically with single-word CAS. Two landmark algorithms address this:
Ellen et al. (2010) designed a lock-free **unbalanced** BST using CAS on
leaf-oriented internal nodes with descriptor objects (similar to MCAS descriptors
from Project 5), and Natarajan and Mittal (2014) simplified the design by using
edge-marking (analogous to Harris's pointer-marking technique from Lecture 07).
Both achieve lock-freedom by allowing concurrent helpers to complete in-progress
operations.

### Tasks

1. Implement the **Natarajan-Mittal lock-free BST** in OCaml 5 supporting
   `insert`, `delete`, and `search` on integer keys. Use `Atomic.compare_and_set`
   with tagged pointers to mark edges for logical deletion. The key challenge is
   handling the **two-step deletion**: first mark the edge to the target node
   (logical delete), then CAS the grandparent's child pointer to physically
   unlink the node.
2. Implement an **optimistic (lazy) locking BST** as a baseline: traverse
   without locks, then lock the relevant nodes, validate that the traversal is
   still correct, and perform the modification. This extends the lazy list
   technique from Lecture 07 to trees.
3. Implement a **coarse-grained locking BST** (single mutex) as a second
   baseline.
4. Verify linearizability of all three using **QCheck-Lin** and **QCheck-STM**:
   model as a sequential sorted set (`Set.Make(Int)`) and test concurrent
   `insert`/`delete`/`search` sequences.
5. Run **TSAN** on the lock-free variant.
6. Benchmark throughput across 1–8 threads under read-heavy (90% `search`),
   balanced (33/33/33), and write-heavy (90% `insert`/`delete`) workloads.
   Compare against the lock-free skip list (Project 11) and the lock-free
   Harris list (Lecture 07) as alternative concurrent sorted-set
   implementations.
7. Measure **tree depth** and **structural degradation** under sustained
   concurrent insertions and deletions (since the tree is unbalanced, it may
   degenerate). Evaluate how key distribution (uniform random vs. sequential
   vs. skewed) affects tree shape and throughput.

### Research Question

Can a lock-free unbalanced BST compete with lock-free skip lists in throughput
for concurrent sorted-set workloads, and how severely does the lack of
rebalancing degrade performance under adversarial key distributions?

### References

- A. Natarajan, N. Mittal, "Fast Concurrent Lock-Free Binary Search Trees," *PPoPP*, 2014
- F. Ellen, P. Fatourou, E. Ruppert, F. van Breugel, "Non-Blocking Binary Search Trees," *PODC*, 2010
- AoMPP Chapter 14 (Skip Lists and Balanced Search)

---

## Project 19: Software Combining Tree for Scalable Shared Counting

**Difficulty: ★★★☆☆** — The status state machine is moderately complex; generalising beyond addition adds design challenge.

### Background

Shared counters are a deceptively simple concurrent object: every thread wants
to `fetchAndIncrement`. Under high contention, even a single `Atomic` counter
becomes a bottleneck as every CAS triggers a cache-line invalidation broadcast.
AoMPP Chapter 12 presents the **software combining tree**, an elegant
alternative: threads are arranged at the leaves of a binary tree and combine
their increments as they move up. At each internal node, the first thread to
arrive waits; the second thread to arrive **combines** both increments into one,
carries the combined value up the tree, and on the way back down distributes the
results. Only *one* CAS reaches the root per pair of concurrent increments,
reducing contention from O(n) to O(log n). The combining tree also generalises
beyond counting — any associative operation can be combined.

### Tasks

1. Implement a **software combining tree** in OCaml 5 that supports
   `fetchAndIncrement`. Build a complete binary tree of nodes, each containing
   an `Atomic` status field (IDLE, FIRST, SECOND, RESULT, ROOT). Threads enter
   at pre-assigned leaves, walk up the tree combining, and walk back down
   distributing results.
2. Generalise the combining tree to support an arbitrary **associative
   combining function** `'a -> 'a -> 'a`, not just addition. Demonstrate it
   with at least two operations (e.g., counting and max-finding).
3. Implement a **simple atomic counter** (`Atomic.fetch_and_add`) and a
   **CAS-loop counter** (`Atomic.compare_and_set` with retry) as baselines.
4. Verify correctness using **QCheck-Lin**: concurrently call `fetchAndIncrement`
   from multiple threads and check that every returned value is unique and that
   the final counter value equals the number of operations.
5. Run **TSAN** to confirm the implementation is race-free.
6. Benchmark throughput (increments/sec) across 2–8 threads. Measure how
   throughput scales with thread count for all three designs. Also measure
   **latency per increment** (wall-clock time from call to return) to capture
   the waiting cost of combining.
7. Investigate the impact of **tree shape** on performance: compare a complete
   binary tree vs. a tree with fan-out 4 (fewer levels, more combining per
   node).

### Research Question

At what thread count does the combining tree's O(log n) contention advantage
overcome its per-operation coordination overhead compared to a simple
`fetch_and_add`, and how does tree fan-out affect the crossover point?

### References

- P. Yew, N. Tzeng, D. Lawrie, "Distributing Hot-Spot Addressing in Large-Scale Multiprocessors," *IEEE TC*, 1987
- AoMPP Chapter 12, Section 12.3 (Software Combining)
- J. M. Mellor-Crummey, M. L. Scott, "Algorithms for Scalable Synchronization," *ACM TOCS*, 1991

---

## Project 20: Counting Networks and Diffracting Trees

**Difficulty: ★★★☆☆** — The bitonic network topology is fixed and well-specified; adding elimination (diffracting tree) raises complexity.

### Background

Counting networks are a hardware-inspired approach to concurrent counting that
avoids both locks and CAS loops entirely. A **balancer** is a simple two-input,
two-output switch that alternates sending tokens to its top and bottom outputs.
By composing balancers into networks — the **bitonic counting network** being
the canonical construction — one obtains a distributed counter where `n` threads
can traverse the network simultaneously with minimal interference. **Diffracting
trees** (Shavit & Zemach, 1996) improve on counting networks by adding
elimination-style collision at each node: if two threads arrive at a balancer
simultaneously, one takes each output without accessing shared state (similar
to the elimination backoff stack from Lecture 08). These structures trade
sequential bottleneck for parallel throughput by spreading contention across the
network.

### Tasks

1. Implement a **bitonic counting network** of width `w` (a power of 2) in
   OCaml 5. Each balancer is a single `Atomic` toggle bit. The network is a
   fixed DAG of balancers; threads traverse the network from input to output
   wires to obtain a distributed count.
2. Implement a **diffracting tree** in OCaml 5: a binary tree of
   **prism nodes** where arriving threads first try to pair up (eliminate) using
   an `Atomic` exchanger; only unpaired threads fall through to the balancer
   and continue down the tree.
3. Implement a **simple atomic counter** as a baseline.
4. Verify the **step property** (quiescent consistency): after `k` tokens have
   traversed the network, the output wire counts form a step sequence (they
   differ by at most 1 and are monotonically distributed). Write a QCheck
   property test that verifies this after bursts of concurrent increments
   followed by quiescent periods.
5. Run **TSAN** on both implementations.
6. Benchmark throughput across 2–8 threads and compare against the combining
   tree (Project 19) and the simple atomic counter. Vary network width to find
   the sweet spot between parallelism and traversal cost.
7. For the diffracting tree, measure the **collision rate** (fraction of
   operations resolved by elimination vs. falling through to the balancer) as
   a function of thread count.

### Research Question

Can counting networks and diffracting trees outperform atomic fetch-and-add on
a multicore system with 2–8 cores, and does the elimination mechanism in
diffracting trees meaningfully reduce traversal depth under high contention?

### References

- J. Aspnes, M. Herlihy, N. Shavit, "Counting Networks," *JACM*, 1994
- N. Shavit, A. Zemach, "Diffracting Trees," *ACM TOPLAS*, 1996
- AoMPP Chapter 12, Sections 12.5 (Counting Networks) and 12.6 (Diffracting Trees)

---

## Project 21: Parallel Sorting — Sorting Networks and Sample Sort

**Difficulty: ★★☆☆☆** — Algorithms are well-known; the main work is parallelisation across OCaml 5 domains and benchmarking.

### Background

Sorting is the canonical parallel problem, and AoMPP Chapter 12 covers two
complementary approaches. **Sorting networks** (e.g., Batcher's bitonic merge
sort) are oblivious — the sequence of comparisons is data-independent and fixed
at compile time, making them naturally parallel but limited to power-of-two
sizes. **Sample sort** (Blelloch et al., 1991) is a practical divide-and-conquer
approach: sample random splitters to partition the input into roughly equal
buckets, sort each bucket independently across threads. Sample sort is the basis
of most practical parallel sorting libraries. This project implements both and
compares their scalability on OCaml 5's multicore runtime.

### Tasks

1. Implement **Batcher's bitonic merge sort** as a sorting network in OCaml 5.
   Represent the network as a sequence of compare-and-swap stages over a shared
   array. Execute each stage in parallel across OCaml 5 domains — each domain
   handles a subset of the independent comparators in that stage.
2. Implement **parallel sample sort** in OCaml 5:
   - Draw `s × (p − 1)` random samples from the input (where `p` is the number
     of domains and `s` is an oversampling factor)
   - Sort the samples and pick `p − 1` evenly-spaced splitters
   - Partition the input into `p` buckets based on the splitters (each domain
     partitions its local chunk)
   - Sort each bucket independently (use a sequential `Array.sort` within each
     domain)
3. Implement a **parallel merge sort** as a simpler baseline: recursively split
   the array, sort halves in parallel across domains, then merge.
4. Benchmark all three algorithms on arrays of 10⁵–10⁷ random integers across
   1–8 domains. Measure **speedup**, **wall-clock time**, and **load balance**
   (max bucket size / average bucket size for sample sort).
5. Investigate the impact of **input distribution** on sample sort's load
   balance: uniform random, sorted, reverse-sorted, many duplicates, and
   skewed (Zipf) distributions.
6. Measure the **sorting network's overhead** from its O(n log² n) comparisons
   (vs. O(n log n) for merge sort) and determine at what input size the
   parallelism compensates.

### Research Question

How does sample sort's practical scalability compare with the oblivious
parallelism of bitonic merge sort on OCaml 5, and at what input sizes and thread
counts does each approach become worthwhile over sequential `Array.sort`?

### References

- K. E. Batcher, "Sorting Networks and Their Applications," *AFIPS*, 1968
- G. E. Blelloch, C. E. Leiserson, B. M. Maggs, C. G. Plaxton, S. J. Smith, M. Zagha, "A Comparison of Sorting Algorithms for the Connection Machine CM-2," *SPAA*, 1991
- AoMPP Chapter 12, Sections 12.7 (Parallel Sorting), 12.8 (Sorting Networks), and 12.9 (Sample Sorting)

---

## Project 22: Memory Reclamation — Hazard Pointers and Epoch-Based Reclamation

**Difficulty: ★★★★☆** — Hazard pointer scanning and epoch tracking require careful lifetime reasoning; demonstrating and preventing ABA is subtle.

### Background

Lock-free data structures that unlink nodes (e.g., the Harris list from
Lecture 07, the Michael-Scott queue from Lecture 08) face a fundamental problem:
when can an unlinked node be safely freed? A concurrent reader may still hold a
reference to it. In languages without GC this is the infamous **ABA problem**
(AoMPP §10.6); in OCaml 5 the GC handles physical memory, but **logical
reclamation** — knowing when a node can be reused or its slot recycled — is
still relevant for bounded pools, caches, and epoch-indexed structures.
**Hazard pointers** (Michael, 2004) let each thread publish the addresses it is
currently accessing; reclaimers scan all hazard pointers before freeing.
**Epoch-based reclamation (EBR)** partitions time into epochs; nodes retired in
epoch `e` are freed once all threads have observed epoch `e + 2`. This project
implements both schemes and applies them to a lock-free data structure.

### Tasks

1. Implement a **hazard pointer library** in OCaml 5: each domain maintains a
   small fixed set of `Atomic` hazard pointer slots. Provide `protect` (publish
   a pointer), `release` (clear a slot), and `retire` (add a node to a
   per-domain retired list; when the list exceeds a threshold, scan all hazard
   pointers and reclaim safe nodes).
2. Implement an **epoch-based reclamation (EBR) library** in OCaml 5: maintain
   a global `Atomic` epoch counter. Each domain has a local epoch that it
   updates on entry to a critical section. Retired nodes are placed in
   epoch-tagged limbo lists and freed when all domains have advanced past that
   epoch.
3. Apply both reclamation schemes to a **lock-free pool** (fixed-size free
   list): nodes are allocated from the pool and returned to it after use.
   Without reclamation, a concurrent pop/push sequence can suffer ABA — the
   pool reuses a node that another thread still references. Demonstrate the ABA
   bug with a test, then show that both HP and EBR prevent it.
4. Integrate one scheme with the **Michael-Scott queue** from Lecture 08 to
   manage node recycling (instead of relying on GC allocation for every
   enqueue).
5. Verify correctness with **QCheck-Lin** and **dscheck**, including stress
   tests designed to trigger ABA (rapid push-pop-push cycles on a small pool).
6. Run **TSAN** on both implementations.
7. Benchmark throughput of the HP-protected and EBR-protected lock-free pool
   against (a) a GC-allocated baseline (plain `Atomic.make` per node) and
   (b) a mutex-protected free list, across 2–8 threads.

### Research Question

What is the throughput cost of hazard pointer scanning vs. epoch-based
reclamation for protecting a lock-free pool, and how does each scheme's
latency profile differ (HP has bounded garbage, EBR can delay reclamation
under stalled threads)?

### References

- M. M. Michael, "Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects," *IEEE TPDS*, 2004
- K. Fraser, "Practical Lock-Freedom," *PhD thesis, University of Cambridge*, 2004, Chapter 5
- AoMPP Chapter 10, Section 10.6 (Memory Reclamation and the ABA Problem)

---

## Project 23: Synchronous Dual Queue

**Difficulty: ★★★★☆** — Reservation nodes and rendezvous coordination on top of the Michael-Scott queue structure require complex CAS logic.

### Background

The standard concurrent queue from Lecture 08 is **asynchronous**: an enqueuer
always succeeds immediately, even if no dequeuer is waiting. A **synchronous
queue** requires that an enqueuer and a dequeuer rendezvous — neither completes
until matched with a partner. This is useful for handoff-style coordination
(e.g., Go channels, Java's `SynchronousQueue`). Scherer, Lea, and Scott (2009)
designed a **dual queue** that unifies both modes: if the queue is empty or
contains only waiters of the same type, an arriving thread enqueues a
**reservation** (a node representing an unfulfilled request); when a complementary
thread arrives, it fulfils the reservation and both proceed. The dual queue is
lock-free and linearizable, built on the Michael-Scott queue structure from
Lecture 08 with reservation nodes.

### Tasks

1. Implement a **lock-free synchronous dual queue** in OCaml 5. The queue holds
   nodes of two types: DATA (an enqueuer waiting for a dequeuer) and REQUEST (a
   dequeuer waiting for an enqueuer). An arriving thread checks the tail: if the
   queue is empty or contains nodes of its own type, it enqueues a reservation
   and spins/parks until fulfilled; otherwise, it fulfils the head reservation
   using CAS.
2. Implement a **simple synchronous exchanger** (pair up two threads using a
   single `Atomic` slot with CAS, as in the elimination array from Lecture 08)
   as a simpler baseline.
3. Implement a **mutex + condition variable synchronous queue** as a blocking
   baseline: the enqueuer waits on a condition variable until a dequeuer arrives,
   and vice versa.
4. Verify correctness using **QCheck-Lin**: model as a sequential synchronous
   queue where `enqueue(v)` blocks until matched with a `dequeue()` that
   returns `v`. The linearization point is the moment of rendezvous.
5. Run **TSAN** on the lock-free implementation.
6. Benchmark rendezvous throughput (matched pairs/sec) across 2–8 threads under:
   (a) balanced (equal enqueuers and dequeuers), (b) enqueue-heavy, and
   (c) dequeue-heavy configurations.
7. Apply the synchronous dual queue to implement a simple **producer-consumer
   pipeline** (e.g., a parallel map where producers generate work items and
   consumers process them with direct handoff, no buffering).

### Research Question

How does the lock-free dual queue's rendezvous throughput compare against a
mutex/condition-based synchronous queue, and does the overhead of reservation
nodes pay off at higher thread counts?

### References

- W. N. Scherer III, D. Lea, M. L. Scott, "Scalable Synchronous Queues," *CACM*, 2009
- AoMPP Chapter 10, Section 10.6.1 (A Naïve Synchronous Queue)
- Java `SynchronousQueue` source code

---

## Project 24: Elimination-Based Concurrent Data Structures Beyond Stacks

**Difficulty: ★★★☆☆** — The elimination technique is taught in Lecture 08; extending it to pools and relaxed queues is a natural next step.

### Background

The elimination backoff stack from Lecture 08 demonstrates a powerful idea:
when two threads with complementary operations (push and pop) collide, they can
**eliminate** each other — exchanging values directly without touching the shared
data structure. This dramatically reduces contention on the central access point.
But elimination is not limited to stacks. Shavit and Touitou (1997) and
subsequent work have applied elimination to other data structures: concurrent
**pools** (bags where any item can be removed), **counters**, and even
**queues** (with relaxed ordering guarantees). The key insight is that any data
structure where "do X then undo X" is a no-op can benefit from elimination. This
project explores how far the elimination technique can be pushed beyond the
textbook stack.

### Tasks

1. Implement the **elimination backoff stack** from Lecture 08 in OCaml 5 as a
   baseline, using an `EliminationArray` of `Atomic` exchanger slots alongside
   a Treiber stack. Benchmark it against the plain Treiber stack.
2. Implement an **elimination-based concurrent pool (bag)** in OCaml 5: a
   collection supporting `put` and `take_any` (remove an arbitrary item). Use
   an array of lock-free stacks (one per domain, for locality) plus an
   elimination array. Two threads calling `put` and `take_any` simultaneously
   can exchange directly.
3. Implement an **elimination-based concurrent exchanger** — a standalone
   two-party rendezvous primitive using a shared `Atomic` slot, timeout, and
   backoff. This is the building block for the other structures.
4. **(Stretch goal)** Implement a **quasi-linearizable elimination queue**: a
   FIFO queue where elimination is permitted between an enqueuer and a dequeuer
   that arrive within a bounded time window, relaxing strict FIFO order for
   throughput.
5. Verify correctness of the stack and pool using **QCheck-Lin** and
   **QCheck-STM**. For the stack, the sequential model is a standard stack;
   for the pool, the sequential model is a multiset (any element can be
   removed).
6. Run **TSAN** on all implementations.
7. Benchmark throughput across 2–8 threads under varying contention levels.
   Measure the **elimination success rate** (fraction of operations resolved
   by direct exchange vs. accessing the backing structure) and its relationship
   to thread count and attempt timeout.
8. Investigate how **elimination array size** and **timeout duration** affect
   throughput and elimination success rate.

### Research Question

How broadly does the elimination technique generalise beyond stacks — does it
provide meaningful throughput gains for pools and relaxed queues, and how
sensitive is the elimination success rate to array sizing and timeout parameters?

### References

- N. Shavit, D. Touitou, "Elimination Trees and the Construction of Pools and Stacks," *Theory of Computing Systems*, 1997
- Y. Afek, G. Korland, E. Yanovsky, "Quasi-Linearizability: Relaxed Consistency for Improved Concurrency," *OPODIS*, 2010
- AoMPP Chapter 11 (Stacks and Elimination)
