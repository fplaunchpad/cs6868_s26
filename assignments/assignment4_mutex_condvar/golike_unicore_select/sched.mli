(** A cooperative round-robin scheduler with trigger support.

    Extends the basic scheduler with handling for {!Trigger.Await},
    enabling blocking synchronization primitives like channels. *)

val fork : (unit -> unit) -> unit
(** [fork f] spawns [f] as a new concurrent fiber. *)

val yield : unit -> unit
(** [yield ()] suspends the current fiber and schedules the next one. *)

val run : (unit -> unit) -> unit
(** [run main] runs [main] and all forked fibers cooperatively.
    Returns when no more fibers are runnable. *)
