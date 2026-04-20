(** Buffered and unbuffered channels for inter-fiber communication.

    - [make 0] creates an unbuffered (rendezvous) channel:
      the sender blocks until a receiver is ready, and vice versa.
    - [make n] creates a buffered channel with capacity [n]:
      sends block only when the buffer is full;
      receives block only when the buffer is empty. *)

type 'a t

val make : int -> 'a t
(** [make capacity] creates a new channel.
    @raise Invalid_argument if [capacity < 0]. *)

val send : 'a t -> 'a -> unit
(** [send ch v] sends [v] on [ch]. Blocks the current fiber if the
    channel is full (or unbuffered with no waiting receiver). *)

val recv : 'a t -> 'a
(** [recv ch] receives a value from [ch]. Blocks the current fiber if
    the channel is empty (or unbuffered with no waiting sender). *)

val recv_evt : 'a t -> 'a Select.event
(** [recv_evt ch] is an event that, when synchronised on, receives from [ch]. *)

val send_evt : 'a t -> 'a -> unit Select.event
(** [send_evt ch v] is an event that, when synchronised on, sends [v] on [ch]. *)
