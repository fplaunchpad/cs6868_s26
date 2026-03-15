(** Elimination array (AoMPP, Chapter 11, Figure 11.7).

    An array of [LockFreeExchanger] slots.  A thread picks a random
    slot in a dynamically chosen subrange and tries to exchange its
    value with another thread at the same slot.

    Used as a back-off mechanism in the EliminationBackoffStack:
    when a CAS on the shared Treiber stack fails, the thread tries
    to "eliminate" its operation by exchanging with a complementary
    operation (push with pop) through the array. *)

type 'a t
(** An elimination array whose exchangers carry values of type ['a]. *)

val create : capacity:int -> 'a t
(** [create ~capacity] allocates [capacity] exchanger slots.
    Each slot is cache-line padded ([Atomic.make_contended]). *)

val visit : 'a t -> 'a -> range:int -> max_rounds:int -> 'a option
(** [visit t value ~range ~max_rounds] picks a random exchanger in
    [0, range) and attempts to exchange [value] within [max_rounds]
    spin iterations.

    Returns [Some partner_value] on success, [None] on timeout. *)
