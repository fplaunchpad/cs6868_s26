(** Lock-free unbounded stack using OCaml's built-in immutable list.

    The shared state is a single [Atomic.t] holding a ['a list].
    Push prepends to the list via CAS; pop removes the head via CAS.
    No custom node type is needed — OCaml's immutable lists are
    inherently safe for concurrent sharing.

    This stack is lock-free: a method call completes in a finite
    number of steps regardless of what other threads do. *)

type 'a t
(** The type of a lock-free stack containing elements of type ['a]. *)

exception Empty
(** Raised by [pop] when the stack is empty. *)

val create : unit -> 'a t
(** [create ()] creates a new empty lock-free stack. *)

val push : 'a t -> 'a -> unit
(** [push s x] pushes [x] onto the top of the stack.
    This operation is lock-free and always succeeds (the stack is unbounded).
    Linearization point: successful CAS on the atomic list reference. *)

val try_pop : 'a t -> 'a option
(** [try_pop s] removes and returns the top element of the stack,
    or [None] if the stack is empty.
    This operation is lock-free.
    Linearization point: successful CAS, or observing an empty list. *)

val pop : 'a t -> 'a
(** [pop s] removes and returns the top element of the stack.
    @raise Empty if the stack is empty.
    This operation is lock-free.
    Linearization point: successful CAS, or observing an empty list. *)
