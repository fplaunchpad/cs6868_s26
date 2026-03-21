type 'a state =
  | Empty of Trigger.t list
  | Filled of 'a

type 'a t = { mutable state : 'a state }

let create () = { state = Empty [] }

let fill ivar v =
  match ivar.state with
  | Filled _ -> failwith "IVar.fill: already filled"
  | Empty triggers ->
      ivar.state <- Filled v;
      List.iter (fun t -> ignore (Trigger.signal t : bool)) triggers

let read ivar =
  match ivar.state with
  | Filled v -> v
  | Empty triggers ->
      let t = Trigger.create () in
      ivar.state <- Empty (t :: triggers);
      Trigger.await t;
      (* After waking, the IVar must be filled *)
      match ivar.state with
      | Filled v -> v
      | Empty _ -> assert false (* impossible: fill always precedes signal *)
