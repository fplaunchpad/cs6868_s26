(** A counting semaphore built on the student's own {!Mutex} and
    {!Condition}.  Any bugs in those primitives surface here. *)

type t = {
  m : Mutex.t;
  c : Condition.t;
  mutable permits : int;
}

let create _n = failwith "Not implemented"

let acquire _s = failwith "Not implemented"

let release _s = failwith "Not implemented"
