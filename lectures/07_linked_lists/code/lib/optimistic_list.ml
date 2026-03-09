(** List using optimistic synchronization.

    Traverse without locking, then lock and validate.
    If validation fails, retry from the beginning.
    This is optimistic because it assumes the common case
    is that the list hasn't changed during traversal.
*)

(** Internal node representation *)
type 'a node = {
  item : 'a option;         (* None for sentinel nodes *)
  key : int;                (* hash code for the item, or min_int/max_int for sentinels *)
  mutable next : 'a node;   (* next node in the list, tail points to itself *)
  lock : Mutex.t;           (* lock for this individual node *)
}

(** The optimistic list type *)
type 'a t = {
  head : 'a node;          (* sentinel node at the start *)
}

(** Create a new empty list with sentinel nodes *)
let create () =
  let rec head = { item = None; key = min_int; next = tail; lock = Mutex.create () }
  and tail = { item = None; key = max_int; next = tail; lock = Mutex.create () } in
  { head }

(** Validate that pred and curr are still adjacent and reachable from head.

    Pre-condition:
      - pred.lock is held
      - curr.lock is held

    Returns true if pred.next = curr and both are still in the list.
*)
let validate head pred curr =
  let rec loop node =
    if node == pred then
      pred.next == curr
    else if node.key < pred.key then
      loop node.next
    else
      false
  in
  loop head

(** Locate position for key without locking (optimistic traversal) *)
let locate head key =
  let rec loop pred curr =
    if curr.key < key then
      loop curr curr.next
    else
      (pred, curr)
  in
  loop head head.next

(** Add an element to the list *)
let add list item =
  let key = Hashtbl.hash item in
  let rec attempt () =
    let (pred, curr) = locate list.head key in
    Mutex.lock pred.lock;
    Mutex.lock curr.lock;
    if validate list.head pred curr then begin
      let result =
        if curr.key = key then
          false  (* element already present *)
        else begin
          (* insert new node between pred and curr *)
          let node = { item = Some item; key; next = curr; lock = Mutex.create () } in
          pred.next <- node;
          true
        end
      in
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      result
    end else begin
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      attempt ()  (* validation failed, retry *)
    end
  in
  attempt ()

(** Remove an element from the list *)
let remove list item =
  let key = Hashtbl.hash item in
  let rec attempt () =
    let (pred, curr) = locate list.head key in
    Mutex.lock pred.lock;
    Mutex.lock curr.lock;
    if validate list.head pred curr then begin
      let result =
        if curr.key = key then begin
          (* element found, remove it *)
          pred.next <- curr.next;
          true
        end else
          false  (* element not present *)
      in
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      result
    end else begin
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      attempt ()  (* validation failed, retry *)
    end
  in
  attempt ()

(** Test whether an element is present *)
let contains list item =
  let key = Hashtbl.hash item in
  let rec attempt () =
    let (pred, curr) = locate list.head key in
    Mutex.lock pred.lock;
    Mutex.lock curr.lock;
    if validate list.head pred curr then begin
      let result = curr.key = key in
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      result
    end else begin
      Mutex.unlock curr.lock;
      Mutex.unlock pred.lock;
      attempt ()  (* validation failed, retry *)
    end
  in
  attempt ()
