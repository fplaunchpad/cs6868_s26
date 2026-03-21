(** A lightweight cooperative scheduler using effect handlers. *)

val fork : (unit -> unit) -> unit
(** [fork f] spawns [f] as a new concurrent task. *)

val yield : unit -> unit
(** [yield ()] suspends the current task and schedules the next one. *)

val run : (unit -> unit) -> unit
(** [run main] runs [main] and all forked tasks in round-robin order. *)
