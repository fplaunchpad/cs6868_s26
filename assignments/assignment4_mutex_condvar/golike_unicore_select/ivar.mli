(** A single-assignment variable.

    An IVar is either empty or filled with a value. Once filled, it
    cannot be changed. Multiple readers can wait on the same IVar;
    all are woken when it is filled. *)

type 'a t

val create : unit -> 'a t
(** Create a new empty IVar. *)

val fill : 'a t -> 'a -> unit
(** [fill ivar v] fills the IVar with [v] and wakes all waiting readers.
    @raise Failure if the IVar is already filled. *)

val read : 'a t -> 'a
(** [read ivar] returns the value if filled, or blocks until it is. *)

val read_evt : 'a t -> 'a Select.event
(** [read_evt ivar] is an event that, when synchronised on, reads from [ivar]. *)
