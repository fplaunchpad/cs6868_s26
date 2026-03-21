(** Async/await built on IVar.

    {[
      Sched.run (fun () ->
        let p = Promise.async (fun () -> expensive_computation ()) in
        (* ... do other work ... *)
        let result = Promise.await p in
        Printf.printf "got %d\n" result)
    ]} *)

type 'a t = 'a Ivar.t

val async : (unit -> 'a) -> 'a t
(** [async f] forks [f] as a concurrent fiber and returns a promise
    for its result. *)

val await : 'a t -> 'a
(** [await p] blocks until the promise is fulfilled and returns the value. *)
