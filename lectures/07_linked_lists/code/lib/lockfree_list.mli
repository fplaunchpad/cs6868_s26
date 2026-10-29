(** Lock-free synchronization list interface *)

module type S = sig
  type 'a t
  (** The type of a lock-free list containing elements of type ['a] *)

  val create : unit -> 'a t
  (** [create ()] creates a new empty list with sentinel nodes *)

  val add : 'a t -> 'a -> bool
  (** [add list item] adds [item] to the list.
      Returns [true] if the element was newly added,
      [false] if it was already present.
      This method is lock-free. *)

  val remove : 'a t -> 'a -> bool
  (** [remove list item] removes [item] from the list.
      Returns [true] if the element was present and removed,
      [false] if it was not present.
      This method is lock-free. *)

  val contains : 'a t -> 'a -> bool
  (** [contains list item] tests whether [item] is present in the list.
      Returns [true] if present, [false] otherwise.
      This method is lock-free (no locks, uses atomic operations). *)
end

module Make (Atomic : Atomic_intf.S) : S
(** [Make (Atomic)] builds the lock-free list on top of the given atomics.
    Instantiate with [Dscheck.TracedAtomic] to model-check it with DSCheck. *)

include S
(** The lock-free list over [Stdlib.Atomic]. *)
