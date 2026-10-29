(** Atomic markable reference implementation *)

module type S = sig
  type 'a t

  val create : 'a -> bool -> 'a t
  val get_reference : 'a t -> 'a
  val get_mark : 'a t -> bool
  val get : 'a t -> bool ref -> 'a
  val compare_and_set :
    'a t -> expected_ref:'a -> new_ref:'a -> expected_mark:bool -> new_mark:bool -> bool
end

module Make (Atomic : Atomic_intf.S) = struct
  type 'a marked_ref = {
    reference : 'a;
    marked : bool;
  }

  type 'a t = 'a marked_ref Atomic.t

  let create reference marked =
    Atomic.make { reference; marked }

  let get_reference amr =
    let mr = Atomic.get amr in
    mr.reference

  let get_mark amr =
    let mr = Atomic.get amr in
    mr.marked

  let get amr marked =
    let mr = Atomic.get amr in
    marked := mr.marked;
    mr.reference

  let compare_and_set amr ~expected_ref ~new_ref ~expected_mark ~new_mark =
    let current = Atomic.get amr in
    (* Check if current state matches expected using physical equality for references *)
    if current.reference == expected_ref && current.marked = expected_mark then
      let new_value = { reference = new_ref; marked = new_mark } in
      Atomic.compare_and_set amr current new_value
    else
      false
end

include Make (Atomic)
