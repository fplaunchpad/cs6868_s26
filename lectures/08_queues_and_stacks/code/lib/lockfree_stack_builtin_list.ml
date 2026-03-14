(** Lock-free unbounded stack using OCaml's built-in immutable list.

    A functional take on the Treiber stack: the shared state is simply
    an [Atomic.t] holding a ['a list].  Because OCaml lists are
    immutable, they can be safely shared across domains without
    copying — a CAS on the atomic reference is all that is needed.

    - push: CAS  old_list  (x :: old_list)
    - pop:  CAS  (x :: rest)  rest

    No custom node type, no mutable next pointers, no sentinel nodes.
    Exponential backoff reduces contention on the single atomic cell. *)

exception Empty

type 'a t = 'a list Atomic.t

(** Backoff helper: exponential backoff using [Domain.cpu_relax]. *)
module Backoff = struct
  type t = { max_delay : int; mutable limit : int }

  let create ?(min_delay = 1) ?(max_delay = 128) () =
    { max_delay; limit = min_delay }

  let backoff t =
    let delay = Random.int (t.limit + 1) in
    for _ = 1 to delay do
      Domain.cpu_relax ()
    done;
    t.limit <- min t.max_delay (t.limit * 2)
end

(** [create ()] returns an empty lock-free stack. *)
let create () : 'a t = Atomic.make []

(** [push s x] pushes [x] onto the stack.  Lock-free with backoff. *)
let push (s : 'a t) x =
  let backoff = Backoff.create () in
  let rec loop () =
    let old = Atomic.get s in
    if Atomic.compare_and_set s old (x :: old) then ()
    else begin
      Backoff.backoff backoff;
      loop ()
    end
  in
  loop ()

(** [try_pop_once s] is a single CAS attempt (textbook [tryPop], Fig 11.4).
    @raise Empty if the stack is empty.
    Returns [Some v] on CAS success, [None] on CAS failure (contention). *)
let try_pop_once (s : 'a t) =
  let old = Atomic.get s in
  match old with
  | [] -> raise Empty
  | x :: rest ->
    if Atomic.compare_and_set s old rest then Some x
    else None

(** [pop s] removes and returns the top element (textbook [pop], Fig 11.4).
    Spins calling [try_pop_once] with exponential backoff on CAS failure.
    @raise Empty if the stack is empty. *)
let pop (s : 'a t) =
  let backoff = Backoff.create () in
  let rec loop () =
    match try_pop_once s with
    | Some v -> v
    | None ->
      Backoff.backoff backoff;
      loop ()
  in
  loop ()

(** [try_pop s] removes and returns [Some v] where [v] is the top
    element, or [None] if the stack is empty.  Lock-free with backoff. *)
let try_pop (s : 'a t) =
  match pop s with
  | v -> Some v
  | exception Empty -> None
