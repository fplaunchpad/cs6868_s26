(** Lock-free exchanger (AoMPP, Chapter 11, Figure 11.6).

    A [LockFreeExchanger] permits two threads to exchange values of
    type ['a].  Thread A calls [exchange slot a], thread B calls
    [exchange slot b]; A receives [b] and B receives [a].

    The exchanger has three states encoded as a variant in a single
    [Atomic.t] — no [AtomicStampedReference] needed, because the
    variant tag is the stamp:

    {[
      Empty                  — slot is free
      Waiting of 'a          — one thread deposited its item, spinning
      Busy of 'a             — partner deposited its item, exchange completing
    ]}

    Protocol (Figure 11.6):

    1. Read slot.
    2. [Empty] → CAS to [Waiting myItem], then spin for a partner.
       If a partner sets the state to [Busy theirItem], read their
       item, reset to [Empty], return it.
       On timeout, CAS back to [Empty] to cancel.
    3. [Waiting theirItem] → CAS to [Busy myItem].  If the CAS
       succeeds, return [theirItem].
    4. [Busy] → two other threads are mid-exchange; retry.

    No ABA problem: CAS uses physical equality on the variant value.
    Each [Waiting v] is a distinct heap allocation, so a slot that
    goes Empty → Waiting(x) → Busy(y) → Empty cannot fool a stale
    CAS that remembered a *different* [Waiting(x')].

    Instead of nanosecond timeouts we spin for a bounded number of
    [Domain.cpu_relax ()] iterations ([max_rounds]).

    Each exchanger uses [Atomic.make_contended] so that adjacent
    exchanger slots in an elimination array occupy separate cache
    lines, avoiding false sharing. *)

(** Internal state of an exchanger slot. *)
type 'a state =
  | Empty
  | Waiting of 'a
  | Busy of 'a

(** An exchanger slot. *)
type 'a t = 'a state Atomic.t

(** [create ()] returns a fresh exchanger in the [Empty] state.
    Uses [Atomic.make_contended] to pad to a full cache line. *)
let create () : 'a t = Atomic.make_contended Empty

(** [exchange slot my_item ~max_rounds] attempts to exchange [my_item]
    with another thread's value within [max_rounds] spin iterations.

    Returns [Some their_item] on a successful exchange, or [None] if
    no partner arrived before the round budget expired.

    Lock-free: a CAS fails only if another thread made progress. *)
let exchange (slot : 'a t) (my_item : 'a) ~max_rounds : 'a option =
  (* Inner loop: we placed [my_offer = Waiting my_item] in the slot.
     Spin until a partner transitions it to [Busy their_item]. *)
  let rec spin_for_partner my_offer n =
    if n <= 0 then begin
      (* Timeout — try to cancel our offer. *)
      if Atomic.compare_and_set slot my_offer Empty then
        None  (* cancelled successfully, no exchange *)
      else
        (* Cancel CAS failed: a partner set it to [Busy their_item]
           between our timeout check and the cancel CAS.  Complete
           the exchange. *)
        let current = Atomic.get slot in
        Atomic.set slot Empty;
        match current with
        | Busy their_item -> Some their_item
        | _ -> None  (* impossible in correct usage *)
    end else
      let current = Atomic.get slot in
      if current == my_offer then begin
        (* Still [Waiting] — no partner yet. *)
        Domain.cpu_relax ();
        spin_for_partner my_offer (n - 1)
      end else
        (* State changed — partner arrived. *)
        match current with
        | Busy their_item ->
          Atomic.set slot Empty;
          Some their_item
        | _ -> None  (* impossible *)
  in
  (* Outer loop: try to enter a state. *)
  let rec try_exchange n =
    if n <= 0 then None
    else
      let current = Atomic.get slot in
      match current with
      | Empty ->
        (* No one here — deposit our item and wait. *)
        let my_offer = Waiting my_item in
        if Atomic.compare_and_set slot current my_offer then
          spin_for_partner my_offer n
        else
          (* Another thread beat us to it — retry. *)
          try_exchange (n - 1)
      | Waiting their_item ->
        (* A thread is waiting — try to complete the exchange. *)
        if Atomic.compare_and_set slot current (Busy my_item) then
          Some their_item
        else
          try_exchange (n - 1)
      | Busy _ ->
        (* Two other threads are mid-exchange — back off and retry. *)
        Domain.cpu_relax ();
        try_exchange (n - 1)
  in
  try_exchange max_rounds
