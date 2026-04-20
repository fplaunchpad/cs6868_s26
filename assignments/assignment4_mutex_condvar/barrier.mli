(** A fiber-level reusable N-party barrier.

    {b Background (not covered in class).}  A barrier is a rendezvous
    primitive for a {e fixed} set of [n] participants.  Every
    participant that calls {!wait} blocks until all [n] of them have
    called {!wait}; at that moment they are all released together and
    the barrier automatically resets for the next round.

    {b When to use one.}  Barriers are the natural tool for phased /
    iterative parallel algorithms where every worker must complete
    phase [i] before any worker starts phase [i+1].  Examples:
    - iterative numerical methods (Jacobi, Gauss-Seidel),
    - BSP (bulk-synchronous parallel) computations,
    - per-round simulations (game of life, n-body).

    {b Example — 4-worker, 3-round computation.}

    {[
      let n = 4 in
      let rounds = 3 in
      let b = Barrier.create n in
      Sched.run (fun () ->
        for id = 0 to n - 1 do
          Sched.fork (fun () ->
            for _r = 1 to rounds do
              (* ... do this round's work for worker [id] ... *)
              Barrier.wait b
              (* after wait returns, all 4 workers are synchronised
                 at the start of the next round *)
            done)
        done)
    ]}

    {b Contrast with semaphore.}  A semaphore with [n] permits would
    let the first [n] arrivals proceed individually; the barrier
    holds all of them until the last arrives, then releases all at
    once.  The barrier also {e resets}, so the same object can be
    used for many rounds.

    {b Reference.}  The POSIX analogue is [pthread_barrier_t] (see
    [pthread_barrier_wait]).  OCaml's standard library does not
    ship one; this is the kind of primitive libraries like
    [Domainslib] provide for parallel workloads.

    {b Implementation note.}  Your barrier is built on your own
    [Mutex] and [Condition].  The standard trick is a {e sense} or
    {e round-counter}: participants record which round they're
    waiting on; the last arrival bumps the round and broadcasts, so
    earlier arrivals wake up, see the round has advanced, and exit.
*)

type t

val create : int -> t
(** [create n] creates a barrier for [n] participants.
    @raise Invalid_argument if [n <= 0]. *)

val wait : t -> unit
(** Block the current fiber until [n] fibers (counting this one)
    have called [wait] on this barrier, then release all of them
    together.  After release, the barrier is automatically reset for
    the next round — the same [t] may be reused indefinitely. *)
