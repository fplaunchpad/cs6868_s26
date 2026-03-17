(** Bounded blocking queue.

    Based on the BoundedQueue from "The Art of Multiprocessor Programming"
    by Herlihy and Shavit (Chapter 10).

    Uses separate enqueue and dequeue locks with condition variables,
    and an atomic size counter tracking the number of elements. This allows
    concurrent enqueue and dequeue operations.

    Key invariant: [size] tracks the number of elements in the queue.
    - [size = capacity] means the queue is full
    [size] may be transiently negative: if a dequeuer takes an item
    that was linked but not yet counted (the enqueuer links the node
    before incrementing [size]), the dequeuer's decrement races ahead.

    Emptiness is checked via the abstract queue ([head.next = None]) rather
    than via the counter, following the 2nd edition of AoMPP.
*)

(** A node in the linked list backing the queue *)
type 'a node = {
  value : 'a;
  mutable next : 'a node option [@atomic];
}


(** The bounded queue type *)
type 'a t = {
  mutable head : 'a node;    (** Sentinel node; head.next is the first real element *)
  mutable tail : 'a node;    (** Last node in the queue *)
  capacity : int;             (** Maximum number of elements *)
  size : int Atomic.t;        (** Number of elements in the queue *)
  enq_lock : Mutex.t;         (** Lock for enqueuers *)
  deq_lock : Mutex.t;         (** Lock for dequeuers *)
  not_full : Condition.t;     (** Signalled when queue is no longer full *)
  not_empty : Condition.t;    (** Signalled when queue is no longer empty *)
}

let create capacity =
  let sentinel = { value = Obj.magic (); next = None } in
  {
    head = sentinel;
    tail = sentinel;
    capacity;
    size = Atomic.make 0;
    enq_lock = Mutex.create ();
    deq_lock = Mutex.create ();
    not_full = Condition.create ();
    not_empty = Condition.create ();
  }

let enq q x =
  Mutex.lock q.enq_lock;
  let must_wake_dequeuers = Fun.protect ~finally:(fun () -> Mutex.unlock q.enq_lock) (fun () ->
    (* Wait while the queue is full *)
    while Atomic.get q.size = q.capacity do
      Condition.wait q.not_full q.enq_lock
    done;
    let node = { value = x; next = None } in
    Atomic.Loc.set [%atomic.loc q.tail.next] (Some node);
    (* Note: the new node is reachable from head and can be dequeued
       before the tail pointer is updated below. *)
    q.tail <- node;
    (* Increment size; if was 0, queue was empty — wake dequeuers *)
    Atomic.fetch_and_add q.size 1 = 0
  ) in
  if must_wake_dequeuers then begin
    Mutex.lock q.deq_lock;
    Fun.protect ~finally:(fun () -> Mutex.unlock q.deq_lock) (fun () ->
      Condition.broadcast q.not_empty
    )
  end

let deq q =
  Mutex.lock q.deq_lock;
  let must_wake_enqueuers, result = Fun.protect ~finally:(fun () -> Mutex.unlock q.deq_lock) (fun () ->
    (* Wait while the abstract queue is empty (head.next = None).
       We check the list structure rather than the size counter, because
       a node is reachable as soon as the enqueuer links it, even before
       size is incremented. This allows size to go transiently negative. *)
    while q.head.next = None do
      Condition.wait q.not_empty q.deq_lock
    done;
    (* head is a sentinel; head.next is the first real element *)
    let first = Option.get q.head.next in
    let v = first.value in
    q.head <- first;
    (* Decrement size; if was at capacity, queue was full — wake enqueuers *)
    (Atomic.fetch_and_add q.size (-1) = q.capacity, v)
  ) in
  if must_wake_enqueuers then begin
    Mutex.lock q.enq_lock;
    Fun.protect ~finally:(fun () -> Mutex.unlock q.enq_lock) (fun () ->
      Condition.broadcast q.not_full
    )
  end;
  result

let try_enq q x =
  Mutex.lock q.enq_lock;
  let must_wake_dequeuers, success = Fun.protect ~finally:(fun () -> Mutex.unlock q.enq_lock) (fun () ->
    if Atomic.get q.size < q.capacity then begin
      let node = { value = x; next = None } in
      Atomic.Loc.set [%atomic.loc q.tail.next] (Some node);
      q.tail <- node;
      (Atomic.fetch_and_add q.size 1 = 0, true)
    end else
      (false, false)
  ) in
  if must_wake_dequeuers then begin
    Mutex.lock q.deq_lock;
    Fun.protect ~finally:(fun () -> Mutex.unlock q.deq_lock) (fun () ->
      Condition.broadcast q.not_empty
    )
  end;
  success

let try_deq q =
  Mutex.lock q.deq_lock;
  let must_wake_enqueuers, result = Fun.protect ~finally:(fun () -> Mutex.unlock q.deq_lock) (fun () ->
    match q.head.next with
    | Some first ->
      let v = first.value in
      q.head <- first;
      (Atomic.fetch_and_add q.size (-1) = q.capacity, Some v)
    | None ->
      (false, None)
  ) in
  if must_wake_enqueuers then begin
    Mutex.lock q.enq_lock;
    Fun.protect ~finally:(fun () -> Mutex.unlock q.enq_lock) (fun () ->
      Condition.broadcast q.not_full
    )
  end;
  result
