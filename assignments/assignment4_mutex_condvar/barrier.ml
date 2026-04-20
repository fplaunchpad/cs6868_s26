(** A reusable N-party barrier.

    Standard "sense-reversing" approach using a [round] counter: each
    fiber notes the current round on entry and waits until either the
    barrier trips (round advances) or, if it is the last arrival, trips
    the barrier itself.
*)

type t = {
  m : Mutex.t;
  c : Condition.t;
  n : int;
  mutable arrived : int;
  mutable round : int;
}

let create _n = failwith "Not implemented"

let wait _b = failwith "Not implemented"
