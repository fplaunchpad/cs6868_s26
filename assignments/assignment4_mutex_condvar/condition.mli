(** A fiber-level condition variable.

    Used in tandem with a {!Mutex}: a fiber holds the mutex, observes
    a condition is false, and calls {!wait} to atomically release the
    mutex and block until another fiber signals.  On return from
    {!wait}, the mutex is re-acquired and held.

    {b Idiom.}  Always call {!wait} inside a predicate loop:
    {[
      Mutex.lock m;
      while not predicate () do
        Condition.wait c m
      done;
      ...;
      Mutex.unlock m
    ]}
    Even though this implementation does not produce spurious wake-ups,
    the loop also protects against the case where another waiter wins
    the mutex first and invalidates the predicate.

    {b Semantics.}  Waiters are released in FIFO order.  [signal]
    releases at most one waiter; [broadcast] releases all currently
    queued waiters.
*)

type t

val create : unit -> t
(** [create ()] returns a new condition variable with no waiters. *)

val wait : t -> Mutex.t -> unit
(** [wait c m] atomically:
    - enqueues the current fiber on [c]'s waiter queue,
    - releases [m],
    - suspends until a signaller wakes this fiber, and
    - re-acquires [m] before returning.

    The caller must hold [m] on entry. *)

val signal : t -> unit
(** [signal c] wakes one waiter on [c] (the oldest by FIFO order),
    or does nothing if there are no waiters. *)

val broadcast : t -> unit
(** [broadcast c] wakes all currently-queued waiters on [c]. *)
