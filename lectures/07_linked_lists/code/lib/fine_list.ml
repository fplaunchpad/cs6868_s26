(** List using fine-grained synchronization (hand-over-hand locking).

    Each node has its own lock. Operations traverse the list using
    "hand-over-hand" locking: lock the next node before unlocking
    the current node, maintaining a constant two-lock window.
*)

(** Internal node representation *)
type 'a node = {
  item : 'a option;         (* None for sentinel nodes *)
  key : int;                (* hash code for the item, or min_int/max_int for sentinels *)
  mutable next : 'a node;   (* next node in the list, tail points to itself *)
  lock : Mutex.t;           (* lock for this individual node *)
}

(** The fine-grained list type *)
type 'a t = {
  head : 'a node;          (* sentinel node at the start *)
}

(** Create a new empty list with sentinel nodes *)
let create () =
  let rec head = { item = None; key = min_int; next = tail; lock = Mutex.create () }
  and tail = { item = None; key = max_int; next = tail; lock = Mutex.create () } in
  { head }

(** Hand-over-hand traversal: find the position where key belongs.

    Pre-condition:
      - pred.lock is held
      - curr.lock is held
      - pred and curr are adjacent nodes (pred.next = curr)

    Post-condition:
      - (returned) pred.lock is held
      - (returned) curr.lock is held
      - pred and curr are adjacent nodes (pred.next = curr)
      - curr.key >= key (curr is the first node with key >= search key)
      - All intermediate locks have been released
*)
let traverse key pred curr =
  let rec loop pred curr =
    if curr.key < key then begin
      let next = curr.next in
      Mutex.unlock pred.lock;
      Mutex.lock next.lock;
      loop curr next
    end else
      (pred, curr)
  in
  loop pred curr

(** Add an element to the list *)
let add list item =
  let key = Hashtbl.hash item in
  let head = list.head in
  Mutex.lock head.lock;
  let first = head.next in
  Mutex.lock first.lock;

  let (pred, curr) = traverse key head first in
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

(** Remove an element from the list *)
let remove list item =
  let key = Hashtbl.hash item in
  let head = list.head in
  Mutex.lock head.lock;
  let first = head.next in
  Mutex.lock first.lock;

  let (pred, curr) = traverse key head first in
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

(** Test whether an element is present *)
let contains list item =
  let key = Hashtbl.hash item in
  let head = list.head in
  Mutex.lock head.lock;
  let first = head.next in
  Mutex.lock first.lock;

  let (pred, curr) = traverse key head first in
  let result = curr.key = key in
  Mutex.unlock curr.lock;
  Mutex.unlock pred.lock;
  result
