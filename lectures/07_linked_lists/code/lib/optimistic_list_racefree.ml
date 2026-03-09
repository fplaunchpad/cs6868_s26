(** Race-free optimistic list using atomic operations.

    This version eliminates data races by using atomic operations
    for the next field, while keeping the optimistic synchronization
    protocol (traverse without locking, then validate).
*)

(** Internal node representation with atomic next field *)
type 'a node = {
  item : 'a option;                    (* None for sentinel nodes *)
  key : int;                           (* hash code for the item *)
  mutable next : 'a node [@atomic];    (* atomic next pointer *)
  lock : Mutex.t;                      (* lock for this individual node *)
}

(** The optimistic list type *)
type 'a t = {
  head : 'a node;
}

(** Create a new empty list with sentinel nodes *)
let create () =
  let rec tail = {
    item = None;
    key = max_int;
    next = tail;                   (* points to itself *)
    lock = Mutex.create ()
  } and head = {
    item = None;
    key = min_int;
    next = tail;
    lock = Mutex.create ()
  } in
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
      let pred_next = Atomic.Loc.get [%atomic.loc pred.next] in
      pred_next == curr
    else if node.key < pred.key then
      loop (Atomic.Loc.get [%atomic.loc node.next])
    else
      false
  in
  loop head

(** Locate position for key without locking (optimistic traversal) *)
let locate head key =
  let rec loop pred =
    let curr = Atomic.Loc.get [%atomic.loc pred.next] in
    if curr.key < key then
      loop curr
    else
      (pred, curr)
  in
  loop head

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
          let node = {
            item = Some item;
            key;
            next = curr;
            lock = Mutex.create ()
          } in
          Atomic.Loc.set [%atomic.loc pred.next] node;
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
          let curr_next = Atomic.Loc.get [%atomic.loc curr.next] in
          Atomic.Loc.set [%atomic.loc pred.next] curr_next;
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
