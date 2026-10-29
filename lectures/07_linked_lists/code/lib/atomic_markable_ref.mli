(** Atomic markable reference - similar to Java's AtomicMarkableReference *)

module type S = sig
  type 'a t
  (** An atomic reference that maintains a mark bit along with the reference *)

  val create : 'a -> bool -> 'a t
  (** [create ref mark] creates a new atomic markable reference *)

  val get_reference : 'a t -> 'a
  (** [get_reference amr] gets the reference value *)

  val get_mark : 'a t -> bool
  (** [get_mark amr] gets the mark value *)

  val get : 'a t -> bool ref -> 'a
  (** [get amr marked] atomically reads both fields, stores the mark in [marked],
      and returns the reference. *)

  val compare_and_set : 'a t -> expected_ref:'a -> new_ref:'a -> expected_mark:bool -> new_mark:bool -> bool
  (** [compare_and_set amr ~expected_ref ~new_ref ~expected_mark ~new_mark]
      atomically sets the value of both the reference and mark to the given
      update values if the current reference is == to the expected reference
      and the current mark is equal to the expected mark.
      Returns true if successful. *)
end

module Make (Atomic : Atomic_intf.S) : S
(** [Make (Atomic)] builds markable references on top of the given atomics.
    Instantiate with [Dscheck.TracedAtomic] to model-check code using it. *)

include S
(** Markable references over [Stdlib.Atomic]. *)
