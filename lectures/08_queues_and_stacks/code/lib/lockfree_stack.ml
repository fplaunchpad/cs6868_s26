(** Lock-free unbounded stack (Treiber stack with exponential backoff).

    Based on "The Art of Multiprocessor Programming" by Herlihy and Shavit
    (Chapter 11, Figures 11.2–11.4).

    The push() method creates a new node, sets its [next] field to the
    current [top], and uses CAS to swing [top] from the old value to
    the new node.  If the CAS fails (another thread modified [top]),
    the method backs off and retries.

    The pop() method reads [top]; if the stack is empty it returns
    [None].  Otherwise it uses CAS to swing [top] from the current
    node to its [next] field.  If the CAS fails the method backs off
    and retries.

    Lock-freedom: a CAS fails only if another thread's CAS succeeded,
    guaranteeing global progress.  Exponential backoff reduces
    contention on the [top] pointer. *)

(** A node in the linked list backing the stack. *)
type 'a node = {
  value : 'a;
  next  : 'a node option;
}

(** The lock-free stack type.
    [top] is an atomic field pointing to the topmost node, or [None]
    if the stack is empty. *)
type 'a t = {
  mutable top : 'a node option [@atomic];
}

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

exception Empty

module AL = Atomic.Loc

(** [create ()] returns an empty lock-free stack. *)
let create () = { top = None }

(** [push s x] pushes [x] onto the stack.  Lock-free with backoff. *)
let push s x =
  let backoff = Backoff.create () in
  let node = { value = x; next = None } in
  let rec loop () =
    let old_top = AL.get [%atomic.loc s.top] in
    (* Point new node's next at the current top.
       Because [node] is freshly allocated and not yet visible to other
       threads, we can safely create a new record with the updated next
       field. *)
    let node = { node with next = old_top } in
    if AL.compare_and_set [%atomic.loc s.top] old_top (Some node) then
      ()
    else begin
      Backoff.backoff backoff;
      loop ()
    end
  in
  loop ()

(** [try_pop_node s] is a single CAS attempt (textbook [tryPop], Fig 11.4).
    @raise Empty if the stack is empty.
    Returns [Some v] on CAS success, [None] on CAS failure (contention). *)
let try_pop_node s =
  let old_top = AL.get [%atomic.loc s.top] in
  match old_top with
  | None -> raise Empty
  | Some node ->
    if AL.compare_and_set [%atomic.loc s.top] old_top node.next then
      Some node.value
    else
      None

(** [pop s] removes and returns the top element (textbook [pop], Fig 11.4).
    Spins calling [try_pop_node] with exponential backoff on CAS failure.
    @raise Empty if the stack is empty. *)
let pop s =
  let backoff = Backoff.create () in
  let rec loop () =
    match try_pop_node s with
    | Some v -> v
    | None ->
      Backoff.backoff backoff;
      loop ()
  in
  loop ()

(** [try_pop s] removes and returns [Some v] where [v] is the top
    element, or [None] if the stack is empty.  Lock-free with backoff. *)
let try_pop s =
  match pop s with
  | v -> Some v
  | exception Empty -> None
