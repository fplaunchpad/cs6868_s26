(** The subset of [Stdlib.Atomic] used by the lock-free implementations.

    Implementations are functors over this signature so that the same
    code can run on real atomics ([Stdlib.Atomic]) or on DSCheck's traced
    atomics ([Dscheck.TracedAtomic]), which let the model checker explore
    every interleaving of the atomic operations. *)

module type S = sig
  type !'a t

  val make : 'a -> 'a t
  val get : 'a t -> 'a
  val set : 'a t -> 'a -> unit
  val compare_and_set : 'a t -> 'a -> 'a -> bool
end
