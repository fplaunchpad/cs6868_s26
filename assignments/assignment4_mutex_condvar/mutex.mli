(** A fiber-level mutex (mutual-exclusion lock).

    {b Semantics.}  At most one fiber holds the lock at any time.  A
    fiber that calls {!lock} on a held mutex is suspended until it is
    woken up with the lock handed to it.  Waiters are served in strict
    FIFO order.

    {b Implementation.}  Built directly on {!Trigger} and a FIFO queue
    of waiters.  Unlocking performs a {e direct hand-off}: the next
    waiter is signaled while the lock stays logically held, so no other
    fiber can steal the lock between unlock and the waiter's wake-up.

    {b Composition with [Select].}  {!lock_evt} exposes lock
    acquisition as a {!Select.event}, so it composes with channel
    events, IVar events, etc.  Example — pick up whichever of two forks
    is free first (the core trick in the dining-philosophers solution):
    {[
      Select.select [ Mutex.lock_evt left; Mutex.lock_evt right ]
    ]}
*)

type t

val create : unit -> t
(** [create ()] returns a new mutex in the unlocked state. *)

val lock : t -> unit
(** [lock m] acquires the mutex, blocking (suspending the calling
    fiber) until it becomes available.  On return, the caller holds
    the mutex. *)

val try_lock : t -> bool
(** [try_lock m] attempts to acquire the mutex without blocking.
    Returns [true] if the lock was acquired, [false] otherwise. *)

val unlock : t -> unit
(** [unlock m] releases the mutex.  The caller must currently hold it;
    calling [unlock] on an unlocked mutex is a programming error. *)

val lock_evt : t -> unit Select.event
(** [lock_evt m] is an event that synchronises on acquiring [m].  When
    the event fires (either eagerly in {!Select.select}'s fast path or
    as the winning case of a blocked select), the caller holds [m]. *)
