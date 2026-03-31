(** Batch Bounded Blocking Queue

    A bounded blocking queue where enqueue and dequeue operate on
    batches of elements atomically, with strict FIFO fairness and
    head-of-line blocking for both enqueue and dequeue waiters.

    Uses a single mutex with per-waiter condition variables. *)

(** A blocked enqueuer waiting for enough free space. *)
type 'a enq_waiter = {
  items : 'a array;       (** The batch of items this thread wants to enqueue *)
  cond : Condition.t;     (** Private condition variable — signaled when this
                              waiter reaches the head and space may be available *)
}

(** A blocked dequeuer waiting for enough items. *)
type 'a deq_waiter = {
  amount : int;           (** Number of items this thread wants to dequeue *)
  cond : Condition.t;     (** Private condition variable — signaled when this
                              waiter reaches the head and items may be available *)
}

type 'a t = {
  mutex : Mutex.t;
  buffer : 'a Queue.t;                   (** Items currently in the queue *)
  capacity : int;
  enq_waiters : 'a enq_waiter Queue.t;   (** FIFO queue of blocked enqueuers *)
  deq_waiters : 'a deq_waiter Queue.t;   (** FIFO queue of blocked dequeuers *)
}

(** [create capacity] initializes a new queue. Validate capacity, then
    initialize all fields of the ['a t] record. *)
let create _capacity = failwith "Not implemented"

let validate_enq_count q n =
  if n <= 0 then
    invalid_arg "BatchQueue: batch size must be positive";
  if n > q.capacity then
    invalid_arg "BatchQueue: batch size exceeds capacity"

let validate_deq_count q n =
  if n <= 0 then
    invalid_arg "BatchQueue: dequeue count must be positive";
  if n > q.capacity then
    invalid_arg "BatchQueue: dequeue count exceeds capacity"

let free_space q = q.capacity - Queue.length q.buffer

(** [notify q] checks the head of each waiter queue and signals it if
    its request can now be satisfied. Call after every enqueue or dequeue. *)
let notify _q = failwith "Not implemented"

(** [enq q items] atomically enqueues all items. Algorithm:
    1. Validate and lock the mutex (use [Fun.protect] for safe unlock).
    2. If [enq_waiters] is non-empty OR not enough free space:
       - Create a waiter, push it to [enq_waiters], and loop on
         [Condition.wait] until this waiter is at the head of
         [enq_waiters] AND there is enough space.
       - Pop self from [enq_waiters].
    3. Push all items into [buffer].
    4. Call [notify]. *)
let enq _q _items = failwith "Not implemented"

(** [deq q n] atomically dequeues [n] items. Symmetric to [enq]:
    wait on [deq_waiters] until at head AND enough items available. *)
let deq _q _n = failwith "Not implemented"

(** [try_enq q items] non-blocking enqueue. If no enqueuers are waiting
    ahead AND enough free space, enqueue and return [true]. Otherwise
    return [false] immediately (do not create a waiter). *)
let try_enq _q _items = failwith "Not implemented"

(** [try_deq q n] non-blocking dequeue. If no dequeuers are waiting
    ahead AND enough items, dequeue and return [Some items]. Otherwise
    return [None] immediately (do not create a waiter). *)
let try_deq _q _n = failwith "Not implemented"

let size _q = failwith "Not implemented"

let capacity _q = failwith "Not implemented"
