(** Lock-free unbounded queue (Michael-Scott queue).

    Based on "The Art of Multiprocessor Programming" by Herlihy and Shavit
    (Chapter 10, Figures 10.9–10.12).

    The enq() method is lazy: it appends a new node in two CAS steps.
    1. CAS the tail node's [next] from [None] to [Some node].
    2. CAS the queue's [tail] from old last to new node.

    Because these two steps are not atomic, every method call must be
    prepared to encounter an incomplete enq() and help finish it by
    advancing [tail] when the tail node already has a successor.

    The deq() method swings [head] from the sentinel to its successor,
    making the successor the new sentinel.  Before doing so, it checks
    whether [head = tail] with a non-null next, which indicates that
    [tail] is lagging behind; the dequeuer helps advance [tail] first
    (Figure 10.14 scenario).

    Lock-freedom: in any infinite execution, some method call completes
    in a finite number of its own steps. A CAS fails only if another
    thread's CAS succeeded, which constitutes global progress. *)

(** A node in the linked list backing the queue.
    [next] is an atomic record field to allow lock-free CAS updates. *)
type 'a node = {
  value : 'a;
  mutable next : 'a node option [@atomic];
}

(** The lock-free queue type.
    [head] points to the sentinel node (its [value] is meaningless).
    [tail] points to the last node, or a node close to it. *)
type 'a t = {
  mutable head : 'a node [@atomic];
  mutable tail : 'a node [@atomic];
}

(** [create ()] allocates a fresh sentinel node and sets both
    [head] and [tail] to point to it. *)
let create () =
  let sentinel = { value = Obj.magic (); next = None } in
  { head = sentinel; tail = sentinel }

module AL = Atomic.Loc

(** [enq q x] appends [x] to the queue.  Lock-free and total
    (the queue is unbounded, so it never fails). *)
let enq q x =
  let node = { value = x; next = None } in
  let rec loop () =
    let last = AL.get [%atomic.loc q.tail] in
    let next = AL.get [%atomic.loc last.next] in
    if last == AL.get [%atomic.loc q.tail] then
      match next with
      | None ->
        if AL.compare_and_set [%atomic.loc last.next] None (Some node)
        then
          ignore (AL.compare_and_set [%atomic.loc q.tail] last node)
        else
          loop ()
      | Some next_node ->
        (* Tail was lagging; help advance it, then retry *)
        ignore (AL.compare_and_set [%atomic.loc q.tail] last next_node);
        loop ()
    else
      loop ()
  in
  loop ()

(** [try_deq q] removes and returns [Some v] where [v] is the first
    element, or [None] if the queue is empty.  Lock-free. *)
let try_deq q =
  let rec loop () =
    let first = AL.get [%atomic.loc q.head] in
    let last  = AL.get [%atomic.loc q.tail] in
    let next  = AL.get [%atomic.loc first.next] in
    if first == AL.get [%atomic.loc q.head] then
      match next with
      | None ->
        None
      | Some next_node ->
        if first == last then begin
          (* Tail is lagging behind; help advance it *)
          ignore (AL.compare_and_set [%atomic.loc q.tail] last next_node);
          loop ()
        end else begin
          let value = next_node.value in
          if AL.compare_and_set [%atomic.loc q.head] first next_node
          then Some value
          else loop ()
        end
    else
      loop ()
  in
  loop ()
