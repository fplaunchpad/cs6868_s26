(** Bounded blocking queue with split-counter optimization.

    Based on the BoundedQueue from "The Art of Multiprocessor Programming"
    by Herlihy and Shavit (Chapter 10), with the split-counter size
    optimization that reduces contention between enqueuers and dequeuers.

    Instead of a single shared [size] counter, the size is split into two:
    - [enq_side_size]: incremented by [enq], always >= 0
    - [deq_side_size]: decremented by [deq], always <= 0

    Actual queue size = [enq_side_size + deq_side_size].

    On the fast path, [enq] only checks [enq_side_size < capacity] —
    since [deq_side_size <= 0], this is a conservative (safe) check.
    When [enq_side_size] reaches [capacity], the enqueuer {i reconciles}:
    it locks [deq_lock], adds [deq_side_size] to [enq_side_size], and
    resets [deq_side_size] to 0. This yields the true queue size without
    requiring synchronization on every call.

    Lock ordering is always [enq_lock] then [deq_lock] to prevent deadlock.
    Emptiness is checked via the abstract queue ([head.next = None]) rather than
    via the counters, following the 2nd edition of AoMPP.
*)

(** A node in the linked list backing the queue *)
type 'a node = {
  value : 'a;
  mutable next : 'a node option [@atomic];
}

(** The bounded queue type with split counters *)
type 'a t = {
  mutable head : 'a node;      (** Sentinel node; head.next is the first real element *)
  mutable tail : 'a node;      (** Last node in the queue *)
  capacity : int;              (** Maximum number of elements *)
  mutable enq_side_size : int; (** Enqueue-side counter, range [0, capacity]. Protected by enq_lock. *)
  mutable deq_side_size : int; (** Dequeue-side counter, range [-capacity, 0]. Protected by deq_lock. *)
  enq_lock : Mutex.t;          (** Lock for enqueuers *)
  deq_lock : Mutex.t;          (** Lock for dequeuers *)
  not_full : Condition.t;      (** Signalled when queue is no longer full *)
  not_empty : Condition.t;     (** Signalled when queue is no longer empty *)
}

let create capacity =
  let sentinel = { value = Obj.magic (); next = None } in
  {
    head = sentinel;
    tail = sentinel;
    capacity;
    enq_side_size = 0;
    deq_side_size = 0;
    enq_lock = Mutex.create ();
    deq_lock = Mutex.create ();
    not_full = Condition.create ();
    not_empty = Condition.create ();
  }

(** [reconcile_enq q] absorbs [deq_side_size] into [enq_side_size] so that
    [enq_side_size] reflects the true queue size.
    Must be called while holding [enq_lock]; acquires [deq_lock] internally. *)
let reconcile_enq q =
  Mutex.lock q.deq_lock;
  let combined = q.enq_side_size + q.deq_side_size in
  q.enq_side_size <- combined;
  q.deq_side_size <- 0;
  Mutex.unlock q.deq_lock

let enq q x =
  Mutex.lock q.enq_lock;
  let must_wake_dequeuers = Fun.protect ~finally:(fun () -> Mutex.unlock q.enq_lock) (fun () ->
    (* Fast path: enq_side_size < capacity means definitely not full *)
    while q.enq_side_size >= q.capacity do
      (* Slow path: reconcile to get the true queue size *)
      reconcile_enq q;
      (* If truly full after reconciliation, block *)
      if q.enq_side_size >= q.capacity then
        Condition.wait q.not_full q.enq_lock
    done;
    let node = { value = x; next = None } in
    Atomic.Loc.set [%atomic.loc q.tail.next] (Some node);
    q.tail <- node;
    let old = q.enq_side_size in
    q.enq_side_size <- old + 1;
    (* If enq_side_size was 0, queue may have been empty — wake dequeuers *)
    old = 0
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
       We check the list structure rather than the counters, because
       a node is reachable as soon as the enqueuer links it, even before
       enq_side_size is incremented. *)
    while q.head.next = None do
      Condition.wait q.not_empty q.deq_lock
    done;
    let first = Option.get q.head.next in
    let v = first.value in
    q.head <- first;
    let old = q.deq_side_size in
    q.deq_side_size <- old - 1;
    (* If deq_side_size was 0, queue may have been full — wake enqueuers.
       deq_side_size = 0 only after enqueuer reconciliation, which happens
       when enq_side_size hit capacity. *)
    (old = 0, v)
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
    let enq_size = q.enq_side_size in
    (* If the local counter says room is available, fast path *)
    let enq_size =
      if enq_size >= q.capacity then begin
        reconcile_enq q;
        q.enq_side_size
      end else
        enq_size
    in
    if enq_size < q.capacity then begin
      let node = { value = x; next = None } in
      q.tail.next <- Some node;
      q.tail <- node;
      q.enq_side_size <- enq_size + 1;
      (enq_size = 0, true)
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
      let old = q.deq_side_size in
      q.deq_side_size <- old - 1;
      (old = 0, Some v)
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
