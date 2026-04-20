(** A fiber-level condition variable.

    Implementation: a plain FIFO queue of triggers.  {!wait} relies on
    the unicore invariant that "no context switch happens unless we
    perform an effect (await / yield / a channel op)" — this is what
    makes the enqueue-then-unlock sequence atomic, without needing any
    extra state-machine gymnastics.
*)

type t = {
  waiters : Trigger.t Queue.t;
}

let create () = failwith "Not implemented"

let wait _c _m = failwith "Not implemented"

(** Pop triggers until one is signalled successfully (skipping stale
    ones — unused here because [Condition] does not participate in
    [Select], but kept for symmetry and future extension). *)
let rec signal_one waiters =
  if Queue.is_empty waiters then ()
  else
    let trigger = Queue.pop waiters in
    if not (Trigger.signal trigger) then signal_one waiters

let signal _c = failwith "Not implemented"

let broadcast _c = failwith "Not implemented"
