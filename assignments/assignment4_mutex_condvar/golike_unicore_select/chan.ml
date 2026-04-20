(** A bounded channel with Go-like semantics and CML-style event support.

    {b Invariants}:

    - [0 <= Queue.length buf <= capacity].
    - For plain [send]/[recv] (outside select), [receivers] has live
      entries only when [buf] is empty, and [senders] has live entries
      only when [buf] is full.
    - When [select] is used, both [receivers] and [senders] may
      contain live entries on the {i same} channel (e.g. a select
      offering both [recv_evt ch] and [send_evt ch v]).  Stale entries
      from lost select races are harmlessly skipped by
      {!find_live_receiver} / {!find_live_sender}.
    - Each trigger is signaled at most once.  Stale entries may linger
      in the queues and are harmlessly skipped. *)
type 'a t = {
  capacity : int;
  buf : 'a Queue.t;
  receivers : ('a option ref * Trigger.t) Queue.t;
  senders : ('a * unit option ref * Trigger.t) Queue.t;
}

let make capacity =
  if capacity < 0 then invalid_arg "Chan.make: negative capacity";
  {
    capacity;
    buf = Queue.create ();
    receivers = Queue.create ();
    senders = Queue.create ();
  }

(* [find_live_receiver receivers v] pops receivers until it finds one whose
   trigger can be signaled (i.e. not a stale select waiter). *)
let rec find_live_receiver receivers v =
  if Queue.is_empty receivers then false
  else
    let (slot, trigger) = Queue.pop receivers in
    slot := Some v;
    if Trigger.signal trigger then true
    else find_live_receiver receivers v

(* [find_live_sender senders] pops senders until it finds one whose trigger
   can be signaled.  Writes [done_slot := Some ()] before signaling so
   the waiter sees it as soon as it wakes.  If the signal fails (stale
   select waiter), the slot write is harmless — nobody will read it —
   and we continue to the next sender. *)
let rec find_live_sender senders =
  if Queue.is_empty senders then None
  else
    let (sv, done_slot, strigger) = Queue.pop senders in
    done_slot := Some ();
    if Trigger.signal strigger then
      Some sv
    else
      find_live_sender senders

let send ch v =
  if find_live_receiver ch.receivers v then
    ()
  else if Queue.length ch.buf < ch.capacity then
    Queue.push v ch.buf
  else begin
    let trigger = Trigger.create () in
    let done_slot = ref None in
    Queue.push (v, done_slot, trigger) ch.senders;
    Trigger.await trigger
  end

let recv ch =
  if not (Queue.is_empty ch.buf) then begin
    let v = Queue.pop ch.buf in
    (match find_live_sender ch.senders with
     | Some sv -> Queue.push sv ch.buf
     | None -> ());
    v
  end else begin
    match find_live_sender ch.senders with
    | Some sv -> sv
    | None ->
        let slot = ref None in
        let trigger = Trigger.create () in
        Queue.push (slot, trigger) ch.receivers;
        Trigger.await trigger;
        Option.get !slot
  end

(* --- Decomposed operations for select support --- *)

let try_complete_recv ch =
  if not (Queue.is_empty ch.buf) then begin
    let v = Queue.pop ch.buf in
    (match find_live_sender ch.senders with
     | Some sv -> Queue.push sv ch.buf
     | None -> ());
    Some v
  end else begin
    match find_live_sender ch.senders with
    | Some sv -> Some sv
    | None -> None
  end

let try_complete_send ch v =
  if find_live_receiver ch.receivers v then true
  else if Queue.length ch.buf < ch.capacity then begin
    Queue.push v ch.buf;
    true
  end else
    false

let enqueue_recv ch slot trigger =
  Queue.push (slot, trigger) ch.receivers

let enqueue_send ch v done_slot trigger =
  Queue.push (v, done_slot, trigger) ch.senders

(* --- CML-style events --- *)

let recv_evt ch = Select.Evt {
  try_complete = (fun () -> try_complete_recv ch);
  offer = (fun slot trigger -> enqueue_recv ch slot trigger);
  wrap = Fun.id;
}

let send_evt ch v = Select.Evt {
  try_complete = (fun () -> if try_complete_send ch v then Some () else None);
  offer = (fun done_slot trigger -> enqueue_send ch v done_slot trigger);
  wrap = Fun.id;
}
