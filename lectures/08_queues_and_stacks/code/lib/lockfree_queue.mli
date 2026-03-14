(** Lock-free unbounded queue.

    Based on the Michael-Scott lock-free queue from
    "The Art of Multiprocessor Programming" by Herlihy and Shavit
    (Chapter 10, Figures 10.9–10.12).

    Uses compare-and-swap (CAS) for both enqueue and dequeue.
    The enq() method is "lazy": it appends a node in two steps:
    1. CAS the tail node's next pointer from null to the new node.
    2. CAS the queue's tail from the old tail to the new node.

    Because these two steps are not atomic, every method call must
    be prepared to encounter an incomplete enq() and "help" finish
    it by advancing the tail pointer.

    This queue is lock-free: a method call completes in a finite
    number of steps regardless of what other threads do. *)

type 'a t
(** The type of a lock-free queue containing elements of type ['a] *)

val create : unit -> 'a t
(** [create ()] creates a new empty lock-free queue. *)

val enq : 'a t -> 'a -> unit
(** [enq q x] appends [x] to the end of the queue.
    This operation is lock-free and always succeeds (the queue is unbounded).
    Linearization point: successful CAS on tail node's next pointer. *)

val try_deq : 'a t -> 'a option
(** [try_deq q] removes and returns the first element of the queue,
    or [None] if the queue is empty.
    This operation is lock-free.
    Linearization point: successful CAS on head, or observing next = None. *)
