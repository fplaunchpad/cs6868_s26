(** Lock-free list using atomic operations.

    Based on Michael's algorithm. Uses AtomicMarkableReference pattern:
    - Each next pointer is atomic and can be marked
    - Marking indicates logical deletion
    - Physical removal happens during find() traversal
*)

module type S = sig
  type 'a t

  val create : unit -> 'a t
  val add : 'a t -> 'a -> bool
  val remove : 'a t -> 'a -> bool
  val contains : 'a t -> 'a -> bool
end

module Make (Atomic : Atomic_intf.S) = struct
  module AMR = Atomic_markable_ref.Make (Atomic)

  (** Internal node representation *)
  type 'a node = {
    item : 'a option;                           (* None for sentinel nodes *)
    key : int;                                  (* hash code or min_int/max_int *)
    next : 'a node AMR.t;                       (* atomic markable reference *)
  }

  (** The lock-free list type *)
  type 'a t = {
    head : 'a node;
  }

  (** Create a new empty list with sentinel nodes *)
  let create () =
    (* Create tail - make it self-referential using a two-step process *)
    let dummy = AMR.create (Obj.magic ()) false in
    let tail = {
      item = None;
      key = max_int;
      next = dummy
    } in
    (* Now update dummy to point to tail itself *)
    let _ = AMR.compare_and_set dummy ~expected_ref:(Obj.magic ()) ~new_ref:tail ~expected_mark:false ~new_mark:false in

    (* Create head pointing to tail *)
    let head = {
      item = None;
      key = min_int;
      next = AMR.create tail false
    } in
    { head }

  (** Find the window (pred, curr) for a given key.

      This method has a dual purpose:
      1. Locate the position for the key
      2. Clean up marked nodes along the way (helping with physical deletion)

      Invariant: On return, pred and curr are unmarked and adjacent,
      with pred.key < key <= curr.key
  *)
  let locate head key =
    let is_marked = ref false in
    let rec retry pred =
      let curr = AMR.get_reference pred.next in
      let rec advance pred curr =
        let succ = AMR.get curr.next is_marked in
        if !is_marked then
          if AMR.compare_and_set pred.next
              ~expected_ref:curr ~new_ref:succ
              ~expected_mark:false ~new_mark:false then
            advance pred succ
          else
            retry head
        else if curr.key >= key then
          (pred, curr)
        else
          advance curr succ
      in
      advance pred curr
    in
    retry head

  (** Add an element to the list *)
  let add list item =
    let key = Hashtbl.hash item in
    let rec attempt () =
      let (pred, curr) = locate list.head key in
      if curr.key = key then false
      else
        let node = { item = Some item; key; next = AMR.create curr false } in
        if AMR.compare_and_set pred.next
             ~expected_ref:curr ~new_ref:node
             ~expected_mark:false ~new_mark:false
        then true
        else attempt ()
    in
    attempt ()

  (** Remove an element from the list **)
  let remove list item =
    let key = Hashtbl.hash item in
    let rec attempt () =
      let (pred, curr) = locate list.head key in
      if not (curr.key == key) then false
      else
        let succ = AMR.get_reference curr.next in
        if AMR.compare_and_set curr.next
             ~expected_ref:succ ~new_ref:succ
             ~expected_mark:false ~new_mark:true
        then begin
          ignore (AMR.compare_and_set pred.next
                    ~expected_ref:curr ~new_ref:succ
                    ~expected_mark:false ~new_mark:false);
          true
        end else
          attempt ()
    in
    attempt ()

  (** Test whether an element is present *)
  let contains list item =
    let key = Hashtbl.hash item in
    (* Direct traversal without helping for better performance on read-heavy workloads *)
    let is_marked = ref false in
    let rec loop curr =
      let next_node = AMR.get curr.next is_marked in
      if !is_marked then
        (* Skip marked nodes *)
        loop next_node
      else if curr.key < key then
        loop next_node
      else
        curr.key = key
    in
    loop list.head
end

include Make (Atomic)
