(** A fiber-level counting semaphore.

    {b Background (not covered in class).}  A counting semaphore is a
    synchronisation primitive holding a non-negative integer count of
    "permits".  Two operations:

    - [acquire] — block until at least one permit is available, then
      consume one (decrement the count).
    - [release] — add a permit (increment the count); if anyone is
      blocked in [acquire], wake one of them.

    {b When to use one.}  A counting semaphore models "at most [k]
    fibers may simultaneously do X".  Classical uses include:
    - bounded resource pools (e.g. "at most 10 outstanding DB
      connections"),
    - rate limiting,
    - implementing producer/consumer with fixed-capacity buffers.

    A {e binary} semaphore (one initial permit) is essentially a
    mutex without ownership tracking — any fiber that called
    [acquire] may [release], whereas a mutex must be unlocked by the
    same fiber that locked it.

    {b Example — "at most 3 workers serving requests at once".}

    {[
      let pool = Semaphore.create 3 in
      Sched.run (fun () ->
        for _ = 1 to 10 do
          Sched.fork (fun () ->
            Semaphore.acquire pool;
            (* ... at most 3 fibers are in here at a time ... *)
            Semaphore.release pool)
        done)
    ]}

    {b Reference.}  OCaml's standard library has an OS-thread-level
    counterpart: {{:https://ocaml.org/manual/latest/api/Semaphore.html}
    [Stdlib.Semaphore]} — its [Counting] submodule has the same
    shape as this one and is worth skimming if the concept is new.

    {b Implementation note.}  Your semaphore is built on top of your
    own [Mutex] and [Condition], not on [Trigger] directly.  One
    mutex protects the permit count; one condition signals waiters
    when a permit becomes available.  The predicate-loop idiom
    (while count = 0 do wait done) is the reason a counting
    semaphore falls out in a few lines.
*)

type t

val create : int -> t
(** [create n] returns a new semaphore initialised with [n] permits.
    A fiber that calls [acquire] at most [n] times before any
    [release] will not block.
    @raise Invalid_argument if [n < 0]. *)

val acquire : t -> unit
(** Block the current fiber until a permit is available, then consume
    one permit. *)

val release : t -> unit
(** Add one permit.  If one or more fibers are currently blocked in
    [acquire], one of them (in FIFO order, following {!Condition}'s
    fairness) is woken. *)
