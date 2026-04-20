# Programming Assignment 4: Fiber-level Mutex & Condition Variables

**Points:** 100
**Duration:** 2 weeks

## Learning Objectives

You've used mutexes and condition variables as black boxes in earlier
assignments.  In this assignment you will **build them yourself**, on
top of the lightweight-concurrency runtime from Lecture 10 (fibers,
triggers, channels, selective communication).

By the end you will understand:

1. The **direct hand-off** pattern for lock release (why unlock signals
   a waiter instead of marking the lock free and letting waiters race).
2. How `Condition.wait` atomically **releases the mutex and blocks**,
   and why that atomicity matters.
3. The difference between **signal** and **broadcast**, and why the
   predicate-loop idiom is still required.
4. How to expose a lock as a **first-class event** (`lock_evt`) that
   composes with channel events in `Select.select` — the CML-style
   selective-communication machinery from Lecture 10.
5. How higher-level primitives (semaphore, barrier) fall out trivially
   once mutex and condition are right.

---

## Background

The runtime for this assignment is the `golike_unicore_select` library
from Lecture 10, vendored into your project.  It provides:

- `Sched.fork : (unit -> unit) -> unit` — spawn a fiber.
- `Sched.yield : unit -> unit` — cooperatively yield.
- `Sched.run : (unit -> unit) -> unit` — run until all fibers finish
  (or deadlock).
- `Trigger.create / await / signal / on_signal` — one-shot signaling
  primitive.  `await` performs an effect that the scheduler handles
  by parking the current fiber until something calls `signal`.
- `Select.event` and `Select.select` — CML-style composable events.
- `Chan` — Go-like channels built on the same machinery (study this
  module — it's the worked example you'll follow).

This is a **unicore cooperative** scheduler: there are no preemptions.
A fiber only yields control at `await`, `Sched.yield`, a channel
operation that blocks, or `Sched.fork`.  Between any two such points
your code runs *atomically* — which makes many implementation concerns
(that would be hairy under preemption) straightforward here.

---

## Your Task

Fill in the bodies of four files.  Every function you need to
implement is stubbed out with `failwith "Not implemented"` — replace
each stub with a real implementation.

1. **`mutex.ml`** — `Mutex.t` with `create`, `lock`, `try_lock`,
   `unlock`, and `lock_evt`.
2. **`condition.ml`** — `Condition.t` with `create`, `wait`, `signal`,
   `broadcast`.
3. **`semaphore.ml`** — counting semaphore built on your `Mutex` +
   `Condition`.
4. **`barrier.ml`** — reusable N-party barrier, same.

You also implement the classic-problem tests in **`test_manual.ml`**.
The QCheck-STM test file (`qcheck_stm_mutex.ml`) is provided — you do
not modify it.

### The `.mli` files are the spec

Each module ships with an `.mli` interface that specifies the public
API and semantics.  **Do not modify the `.mli` files.**  Read them
first — they tell you exactly what each function must do.

### Key implementation issues

Read these carefully before you start writing:

1. **Direct hand-off on unlock.**  When `Mutex.unlock` sees a waiter,
   it must signal that waiter *while keeping the mutex logically
   locked*.  If you instead set `locked := false` and let the waiter
   retry from the top of `lock`, another fiber can grab the lock
   between "set false" and "waiter resumes" — breaking FIFO.  This is
   exactly what `Chan.find_live_sender` does; study it.

2. **Stale waiters from `Select.select`.**  A waiter inserted by
   `lock_evt`'s `offer` function might have been signalled through a
   different case of the same select.  When unlock pops it and calls
   `Trigger.signal`, signal returns `false`.  Skip it and try the next
   waiter — again, `Chan.find_live_sender` shows the pattern.

3. **`Condition.wait` atomicity.**  `wait` must enqueue the waiter,
   release the mutex, and block — in that order, as a conceptual
   atom.  On unicore, this means no `yield` or `await` can happen
   between the enqueue and the release.  Verify this by reading your
   code and identifying the single suspension point.

4. **`Condition.wait` re-acquires the mutex before returning.**  This
   is the POSIX contract: on return from `wait`, the caller holds the
   mutex again.  An autograder test checks this explicitly.

5. **Predicate loop in the caller.**  Even with reliable signalling,
   between the signal and the waiter's re-acquisition of the mutex,
   another fiber may change state and invalidate the condition.  The
   standard idiom is:
   ```ocaml
   Mutex.lock m;
   while not (ready ()) do Condition.wait c m done;
   ...;
   Mutex.unlock m
   ```

6. **`Mutex.lock_evt`.**  Expose lock acquisition as a
   `Select.event`.  The event's `try_complete` takes the lock
   eagerly if free, `offer` enqueues a `(slot, trigger)` pair.  The
   unlock path writes `slot := Some ()` and signals — the same ritual
   `Chan` performs for senders/receivers.

7. **`Semaphore` and `Barrier` are built on YOUR `Mutex` and
   `Condition`.**  Any bugs in those primitives will show up here.
   This is a feature, not a bug.

### Files layout

```
student_template/
├── mutex.mli / mutex.ml          ← implement
├── condition.mli / condition.ml  ← implement
├── semaphore.mli / semaphore.ml  ← implement
├── barrier.mli / barrier.ml      ← implement
├── test_manual.ml                ← implement (classic problems)
├── qcheck_stm_mutex.ml           ← provided; do not modify
├── golike_unicore_select/        ← vendored runtime; do not modify
├── dune / dune-project / Makefile
```

---

## Building and Testing

```bash
make build        # compile everything
make test-manual  # run manual (classic-problem) tests
make test-stm     # run QCheck-STM sequential test
make test         # everything
```

`make test-manual` runs the eight classic-problem tests in
`test_manual.ml`.  If all are implemented, all pass.  The output is
self-explanatory (one line per test).

---

## Grading Rubric (100 points)

| Component | Points | What it checks |
|-----------|--------|----------------|
| Mutex tests | 25 | create / try_lock / unlock / FIFO hand-off / `lock_evt` (fast + blocking + channel composition) |
| Condition tests | 20 | signal wakes exactly one, broadcast wakes all, wait re-acquires the mutex, predicate-loop idiom |
| Semaphore + Barrier | 15 | K-concurrent bound, reusable N-party barrier |
| Fairness / FIFO | 10 | Mutex waiter ordering, Condition waiter ordering |
| Classic-problem tests | 10 | Bounded buffer stress, readers/writers exclusion |
| Manual tests | 10 | Your `test_manual.ml` compiles and every test passes |
| QCheck-STM | 10 | Sequential state-machine test of `Mutex` passes |
| **Total** | **100** | |

The autograder runs against your submission automatically.  The
scripts are the same ones used to grade your final submission — if
they pass locally, they'll pass on the grader.

---

## Submission

Submit a single `.zip` containing these files at the top level
(not inside a folder):

1. `mutex.ml`
2. `condition.ml`
3. `semaphore.ml`
4. `barrier.ml`
5. `test_manual.ml`

Do not include the `golike_unicore_select/` directory, `.mli` files,
or `qcheck_stm_mutex.ml` — the grader uses its own copies of those.

---

## Schedule (2 weeks)

- **Week 1, days 1–3.**  Read Lecture 10 slides, study `chan.ml` in
  the vendored runtime carefully.  Implement `Mutex` including
  `lock_evt`.  Write the three mutex tests in `test_manual.ml`.
- **Week 1, days 4–7.**  Implement `Condition`.  Write the bounded
  buffer and readers/writers tests.  By end of week 1, manual tests
  1–5 should pass.
- **Week 2, days 1–4.**  Implement `Semaphore` and `Barrier`.  Write
  the remaining tests.  Run the autograder locally and iterate until
  all categories pass.
- **Week 2, days 5–7.**  Polish.  Re-read your code; remove any
  unnecessary complexity; ensure your invariants (stated as comments
  on `type t`) actually hold.

---

## Hints and Common Pitfalls

- **"Why does my test deadlock?"**  On unicore, a deadlock manifests
  as `Sched.run` returning *early* with fewer things done than
  expected — the scheduler finds no runnable fibers and exits.  If
  your counter isn't reaching the expected value, some fibers
  parked on a trigger that never got signaled.
- **"Why does `Condition.signal` hit `Trigger.signal` returning
  false?"**  It shouldn't, since Condition doesn't participate in
  `Select`.  If you see this, you're signalling a waiter that was
  already signalled — likely a double-signal bug.
- **`Mutex.unlock` on an unlocked mutex** is a programmer error
  (`failwith`).  Check all your code paths — `Fun.protect` can help
  keep unlocks matched with locks.
- **Re-read `chan.ml`.**  Seriously.  Its `find_live_sender`,
  `send`, `recv`, `send_evt`, and `recv_evt` functions contain every
  pattern you need.  Spend an hour understanding that module before
  writing a line of mutex.ml.

---

Good luck!
