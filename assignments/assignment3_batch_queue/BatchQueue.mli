(** Batch Bounded Blocking Queue

    A bounded blocking queue where enqueue and dequeue operate on
    batches of elements atomically. Blocked operations are served
    in strict FIFO order with head-of-line blocking: a smaller
    request cannot jump ahead of a larger one, even if it could
    be satisfied immediately. *)

(** The type of a batch bounded blocking queue holding values of type ['a]. *)
type 'a t

val create : int -> 'a t
(** [create capacity] creates a queue with the given max capacity.
    @raise Invalid_argument if [capacity <= 0] *)

val enq : 'a t -> 'a array -> unit
(** [enq q items] atomically enqueues all [items]. Blocks if there is
    insufficient space or if another enqueuer is waiting ahead (FIFO).
    @raise Invalid_argument if [Array.length items = 0] or [> capacity] *)

val deq : 'a t -> int -> 'a array
(** [deq q n] atomically dequeues [n] items, returned in FIFO order.
    Blocks if there are fewer than [n] items or if another dequeuer
    is waiting ahead (FIFO).
    @raise Invalid_argument if [n <= 0] or [n > capacity] *)

val try_enq : 'a t -> 'a array -> bool
(** [try_enq q items] attempts a non-blocking enqueue. Returns [true]
    if all items were enqueued, [false] if there is insufficient space
    or other enqueuers are waiting ahead.
    @raise Invalid_argument if [Array.length items = 0] or [> capacity] *)

val try_deq : 'a t -> int -> 'a array option
(** [try_deq q n] attempts a non-blocking dequeue. Returns [Some items]
    if [n] items were available and no other dequeuers are waiting ahead,
    [None] otherwise.
    @raise Invalid_argument if [n <= 0] or [n > capacity] *)

val size : 'a t -> int
(** [size q] returns the current number of items in the queue. *)

val capacity : 'a t -> int
(** [capacity q] returns the maximum capacity of the queue. *)
