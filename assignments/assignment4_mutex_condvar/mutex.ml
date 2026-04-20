(** A fiber-level mutex.

    Invariants:
    - [waiters] is non-empty  ⇒  [locked = true].  (If the mutex were
      unlocked with a waiter present, {!unlock} would have handed it
      off directly.)
    - Each trigger in [waiters] is signaled at most once.  Stale
      entries (signaled via a select race on another case) may linger
      and are harmlessly skipped by {!find_live_waiter}.

    The shape mirrors [Chan] in [golike_unicore_select]: a state field
    plus a FIFO queue of [(slot, trigger)] pairs.  [slot := Some ()] is
    the flag an unlocker writes before signaling, so that when the
    waiter wakes it can distinguish "lock granted to me" from "select
    chose a different case".
*)

type t = {
  mutable locked : bool;
  waiters : (unit option ref * Trigger.t) Queue.t;
}

let create () = failwith "Not implemented"

(** Pop waiters until one is signaled successfully.  A failed signal
    means the waiter was already woken by another case of its
    [Select.select], so we simply try the next one.  Returns [true] if
    a live waiter was found (in which case the lock has been handed
    off), [false] if the queue was drained. *)
let rec find_live_waiter _waiters = failwith "Not implemented"

let lock _m = failwith "Not implemented"

let try_lock _m = failwith "Not implemented"

let unlock _m = failwith "Not implemented"

let lock_evt _m = failwith "Not implemented"
