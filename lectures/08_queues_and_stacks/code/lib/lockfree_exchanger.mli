(** Lock-free exchanger (AoMPP, Chapter 11, Figure 11.6).

    Allows two threads to swap values of type ['a] without locks.
    The first thread to arrive deposits its item and spins; the
    second thread completes the exchange by depositing its own item
    and taking the first thread's.

    Three states — [Empty], [Waiting], [Busy] — are encoded as a
    variant in a single [Atomic.t].  No [AtomicStampedReference] is
    needed: the variant tag serves as the stamp, and physical equality
    of the heap-allocated [Waiting] value prevents ABA.

    Uses [Atomic.make_contended] to avoid false sharing when multiple
    exchangers sit in an array. *)

type 'a t
(** The type of a lock-free exchanger for values of type ['a]. *)

val create : unit -> 'a t
(** [create ()] returns a fresh exchanger in the empty state. *)

val exchange : 'a t -> 'a -> max_rounds:int -> 'a option
(** [exchange slot my_item ~max_rounds] tries to exchange [my_item]
    with another thread's value within [max_rounds] spin iterations
    of [Domain.cpu_relax ()].

    Returns [Some their_item] on a successful exchange, or [None] on
    timeout (no partner arrived within the budget).

    Linearization point: on success, the CAS that transitions the
    slot from [Waiting] to [Busy] (this is the point at which both
    threads commit to the exchange). *)
