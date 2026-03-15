(** Elimination backoff stack (AoMPP, Chapter 11, Figures 11.8–11.9).

    A lock-free linearizable stack that combines a Treiber stack with
    an [EliminationArray] for back-off under contention.

    Under low contention, push and pop complete via a single CAS on
    the Treiber stack's [top] pointer — same as a plain lock-free
    stack.  When a CAS fails (contention), the thread backs off to
    the [EliminationArray] and tries to pair with a complementary
    operation:

    - A push offers [Some value]; if it exchanges with [None]
      (a pop), both operations are "eliminated" without touching
      the shared stack.
    - A pop offers [None]; if it exchanges with [Some v]
      (a push), it receives the pushed value.

    Linearizability:

    - Successful stack-path operations linearize at their CAS.
    - Eliminated push/pop pairs linearize at the CAS that transitions
      the exchanger from [Waiting] to [Busy] — they could have taken
      effect at any point during their concurrent overlap, and the
      stack's state would be the same.

    Lock-freedom: every CAS failure implies some other thread made
    progress.

    == Range policy (domain-local) ==

    Each domain maintains a [range] that controls how many exchanger
    slots the thread considers.  On a successful elimination the
    range grows; on a timeout it shrinks.  This adapts to load:

    - Few threads → small range → higher chance of meeting a partner.
    - Many threads → large range → less exchanger contention.

    The range is stored in [Domain.DLS] (domain-local storage). *)

exception Empty

(** The stack type.

    - [top]: the Treiber stack (an atomic immutable list).
    - [elim]: the elimination array, carrying ['a option] values
      ([Some v] for push, [None] for pop).
    - [capacity]: number of exchanger slots. *)
type 'a t = {
  top      : 'a list Atomic.t;
  elim     : 'a option Elimination_array.t;
  capacity : int;
}

(* ----- Range policy (domain-local) --------------------------------- *)

(** Domain-local mutable range, shared across all stacks on this
    domain.  Initialized to 1; grows on success, shrinks on timeout,
    clamped to the stack's [capacity] at use-site. *)
let range_key : int ref Domain.DLS.key =
  Domain.DLS.new_key (fun () -> ref 1)

let get_range capacity =
  let r = Domain.DLS.get range_key in
  min !r capacity

let record_elimination_success capacity =
  let r = Domain.DLS.get range_key in
  r := min (!r + 1) capacity

let record_elimination_timeout () =
  let r = Domain.DLS.get range_key in
  r := max (!r - 1) 1

(* ----- Treiber stack helpers --------------------------------------- *)

(** Maximum number of [cpu_relax] iterations when spinning in the
    exchanger. *)
let elim_max_rounds = 128

(** [try_push s x] attempts a single CAS to push [x].
    Returns [true] on success. *)
let try_push (s : 'a t) (x : 'a) : bool =
  let old = Atomic.get s.top in
  Atomic.compare_and_set s.top old (x :: old)

(** [try_pop s] attempts a single CAS to pop.
    Returns [Some v] on success, [None] if the CAS fails (contention).
    @raise Empty if the stack is empty. *)
let try_pop_once (s : 'a t) =
  let old = Atomic.get s.top in
  match old with
  | [] -> raise Empty
  | x :: rest ->
    if Atomic.compare_and_set s.top old rest then Some x
    else None

(* ----- Public API -------------------------------------------------- *)

(** [create ~capacity ()] builds an empty elimination backoff stack
    with [capacity] exchanger slots.
    Default [capacity] is 8. *)
let create ?(capacity = 8) () : 'a t = {
  top      = Atomic.make [];
  elim     = Elimination_array.create ~capacity;
  capacity;
}

(** [push s x] pushes [x] onto the stack.  Lock-free.

    1. Try a direct CAS on [top].
    2. On CAS failure, visit the elimination array offering [Some x].
       - If a pop partner exchanges [None], the push is eliminated.
       - Otherwise retry from step 1. *)
let push (s : 'a t) (x : 'a) : unit =
  let rec loop () =
    if try_push s x then ()
    else
      let range = get_range s.capacity in
      match Elimination_array.visit s.elim (Some x)
              ~range ~max_rounds:elim_max_rounds with
      | Some None ->
        (* Exchanged with a pop — eliminated! *)
        record_elimination_success s.capacity
      | Some (Some _) ->
        (* Exchanged with another push — wrong partner, retry. *)
        record_elimination_timeout ();
        loop ()
      | None ->
        (* Timeout — no partner found, retry. *)
        record_elimination_timeout ();
        loop ()
  in
  loop ()

(** [pop s] removes and returns the top element.  Lock-free.
    @raise Empty if the stack is empty.

    1. Try a direct CAS on [top].
    2. On CAS failure, visit the elimination array offering [None].
       - If a push partner exchanges [Some v], pop is eliminated.
       - Otherwise retry from step 1. *)
let pop (s : 'a t) : 'a =
  let rec loop () =
    match try_pop_once s with
    | Some v -> v
    | None ->
      let range = get_range s.capacity in
      (match Elimination_array.visit s.elim None
               ~range ~max_rounds:elim_max_rounds with
       | Some (Some v) ->
         (* Exchanged with a push — eliminated! *)
         record_elimination_success s.capacity;
         v
       | Some None ->
         (* Exchanged with another pop — wrong partner, retry. *)
         record_elimination_timeout ();
         loop ()
       | None ->
         (* Timeout — no partner found, retry. *)
         record_elimination_timeout ();
         loop ())
  in
  loop ()

(** [try_pop s] removes and returns [Some v] where [v] is the top
    element, or [None] if the stack is empty.  Lock-free. *)
let try_pop (s : 'a t) : 'a option =
  match pop s with
  | v -> Some v
  | exception Empty -> None
