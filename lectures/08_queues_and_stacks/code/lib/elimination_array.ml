(** Elimination array (AoMPP, Chapter 11, Figure 11.7).

    An [EliminationArray] is an array of [LockFreeExchanger] slots.
    A thread calling [visit] picks a random slot in a caller-chosen
    subrange and attempts to exchange its value with whatever thread
    happens to pick the same slot.

    In the EliminationBackoffStack, push threads offer their value
    and pop threads offer [None]; a successful push/pop exchange
    means both operations complete without touching the shared
    Treiber stack.

    Each exchanger slot uses [Atomic.make_contended] to sit on its
    own cache line, avoiding false sharing between adjacent slots. *)

type 'a t = 'a Lockfree_exchanger.t array

(** [create ~capacity] returns an elimination array with [capacity]
    exchanger slots, each padded to avoid false sharing. *)
let create ~capacity : 'a t =
  Array.init capacity (fun _ -> Lockfree_exchanger.create ())

(** [visit t value ~range ~max_rounds] picks a random slot in
    [0, range) and tries to exchange [value] with another thread
    within [max_rounds] spin iterations.

    [Random.int] is domain-local in OCaml 5, so no extra per-domain
    RNG setup is needed.

    Returns [Some their_value] on a successful exchange, or [None]
    on timeout. *)
let visit (t : 'a t) (value : 'a) ~range ~max_rounds : 'a option =
  let slot = Random.int range in
  Lockfree_exchanger.exchange t.(slot) value ~max_rounds
