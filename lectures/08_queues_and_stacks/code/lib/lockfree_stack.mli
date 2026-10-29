(** Lock-free unbounded stack (Treiber stack with exponential backoff).

    Based on "The Art of Multiprocessor Programming" by Herlihy and Shavit
    (Chapter 11, Figures 11.2–11.4).

    Uses compare-and-swap (CAS) for both push and pop.
    The push() method CAS-es the top pointer from the old top to a new
    node whose next field points to the old top.
    The pop() method CAS-es the top pointer from the old top to its
    successor.

    Both methods use exponential backoff to reduce contention on the
    top pointer.

    This stack is lock-free: a method call completes in a finite
    number of steps regardless of what other threads do. *)

exception Empty
(** Raised by [pop] when the stack is empty. *)

module type S = sig
  type 'a t
  (** The type of a lock-free stack containing elements of type ['a]. *)

  val create : unit -> 'a t
  (** [create ()] creates a new empty lock-free stack. *)

  val push : 'a t -> 'a -> unit
  (** [push s x] pushes [x] onto the top of the stack.
      This operation is lock-free and always succeeds (the stack is unbounded).
      Linearization point: successful CAS on [top]. *)

  val try_pop : 'a t -> 'a option
  (** [try_pop s] removes and returns the top element of the stack,
      or [None] if the stack is empty.
      This operation is lock-free.
      Linearization point: successful CAS on [top], or observing [top = None]. *)

  val pop : 'a t -> 'a
  (** [pop s] removes and returns the top element of the stack.
      @raise Empty if the stack is empty.
      This operation is lock-free.
      Linearization point: successful CAS on [top], or observing [top = None]. *)
end

module Make (Atomic : Atomic_intf.S) (Backoff : Backoff.S) : S
(** [Make (Atomic) (Backoff)] builds the stack on the given atomics and
    backoff.  Instantiate with [Dscheck.TracedAtomic] and
    [Backoff.No_backoff] to model-check it with DSCheck. *)

include S
(** The stack over [Stdlib.Atomic] with exponential backoff. *)
