(** Elimination backoff stack (AoMPP, Chapter 11, Figures 11.8–11.9).

    A lock-free linearizable stack that combines a Treiber stack with
    an {!Elimination_array} for back-off under contention.

    Under low contention, operations complete via CAS on the shared
    [top] pointer.  Under high contention, complementary push/pop
    pairs "eliminate" each other through the array without touching
    the shared stack, turning contention into parallelism.

    This stack is lock-free: push and pop always complete in a
    finite number of steps. *)

type 'a t
(** The type of an elimination backoff stack containing elements of
    type ['a]. *)

exception Empty
(** Raised by [pop] when the stack is empty. *)

val create : ?capacity:int -> unit -> 'a t
(** [create ~capacity ()] creates an empty elimination backoff stack.
    [capacity] is the number of exchanger slots in the elimination
    array (default 8).  Each slot is cache-line padded. *)

val push : 'a t -> 'a -> unit
(** [push s x] pushes [x] onto the stack.  Lock-free.
    Linearization point: successful CAS on [top], or the CAS that
    completes an elimination exchange. *)

val try_pop : 'a t -> 'a option
(** [try_pop s] removes and returns the top element, or [None] if
    the stack is empty.  Lock-free.
    Linearization point: successful CAS on [top], observation of an
    empty list, or the CAS that completes an elimination exchange. *)

val pop : 'a t -> 'a
(** [pop s] removes and returns the top element.
    @raise Empty if the stack is empty.
    Lock-free.
    Linearization point: same as [try_pop]. *)
