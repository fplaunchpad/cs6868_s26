(** Backoff for retry loops after a failed CAS.

    The lock-free stacks are functors over [S] so that tests can swap the
    randomised exponential backoff for [No_backoff]: model checkers like
    DSCheck need every run of the program to be deterministic. *)

module type S = sig
  type t

  val create : unit -> t
  val backoff : t -> unit
end

(** Exponential backoff using [Domain.cpu_relax]. *)
type t = { max_delay : int; mutable limit : int }

let create () = { max_delay = 128; limit = 1 }

let backoff t =
  let delay = Random.int (t.limit + 1) in
  for _ = 1 to delay do
    Domain.cpu_relax ()
  done;
  t.limit <- min t.max_delay (t.limit * 2)

(** No backoff at all: retry immediately. *)
module No_backoff = struct
  type t = unit

  let create () = ()
  let backoff () = ()
end
