type 'a state =
  | Empty of { receivers : ('a option ref * Trigger.t) Queue.t }
  | NotEmpty of { buf : 'a Queue.t }
  | Full of { buf : 'a Queue.t; senders : ('a * Trigger.t) Queue.t }

type 'a t = {
  capacity : int;
  mutable state : 'a state;
}

let make capacity =
  if capacity < 0 then invalid_arg "Chan.make: negative capacity";
  { capacity; state = Empty { receivers = Queue.create () } }

let send ch v =
  match ch.state with
  | Empty { receivers } ->
      if not (Queue.is_empty receivers) then begin
        (* Receiver waiting — transfer directly *)
        let (slot, trigger) = Queue.pop receivers in
        slot := Some v;
        ignore (Trigger.signal trigger : bool)
      end else if ch.capacity > 0 then begin
        (* Buffer has room (was empty, capacity > 0) *)
        let buf = Queue.create () in
        Queue.push v buf;
        ch.state <- NotEmpty { buf }
      end else begin
        (* Unbuffered, no receiver — must block *)
        let trigger = Trigger.create () in
        let senders = Queue.create () in
        Queue.push (v, trigger) senders;
        ch.state <- Full { buf = Queue.create (); senders };
        Trigger.await trigger
      end
  | NotEmpty { buf } ->
      if Queue.length buf < ch.capacity then
        Queue.push v buf
      else begin
        (* Buffer full — must block *)
        let trigger = Trigger.create () in
        let senders = Queue.create () in
        Queue.push (v, trigger) senders;
        ch.state <- Full { buf; senders };
        Trigger.await trigger
      end
  | Full { senders; _ } ->
      (* Already full with blocked senders — join the queue *)
      let trigger = Trigger.create () in
      Queue.push (v, trigger) senders;
      Trigger.await trigger

let recv ch =
  match ch.state with
  | Empty { receivers } ->
      (* Nothing available — must block *)
      let slot = ref None in
      let trigger = Trigger.create () in
      Queue.push (slot, trigger) receivers;
      Trigger.await trigger;
      (match !slot with
       | Some v -> v
       | None -> assert false (* impossible: signal always fills slot before waking *))
  | NotEmpty { buf } ->
      let v = Queue.pop buf in
      if Queue.is_empty buf then
        ch.state <- Empty { receivers = Queue.create () };
      v
  | Full { buf; senders } ->
      (* Wake a blocked sender *)
      let (sv, strigger) = Queue.pop senders in
      ignore (Trigger.signal strigger : bool);
      let v =
        if Queue.is_empty buf then
          sv (* unbuffered: direct transfer from sender *)
        else begin
          let v = Queue.pop buf in
          Queue.push sv buf;
          v
        end
      in
      if Queue.is_empty senders then begin
        if Queue.is_empty buf then
          ch.state <- Empty { receivers = Queue.create () }
        else
          ch.state <- NotEmpty { buf }
      end;
      v
