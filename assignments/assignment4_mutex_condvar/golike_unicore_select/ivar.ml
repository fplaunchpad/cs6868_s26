type 'a state =
  | Empty of ('a option ref * Trigger.t) list
  | Filled of 'a

type 'a t = { mutable state : 'a state }

let create () = { state = Empty [] }

let fill ivar v =
  match ivar.state with
  | Filled _ -> failwith "IVar.fill: already filled"
  | Empty waiters ->
      ivar.state <- Filled v;
      List.iter (fun (slot, t) ->
        slot := Some v;
        ignore (Trigger.signal t : bool)
      ) waiters

let read ivar =
  match ivar.state with
  | Filled v -> v
  | Empty waiters ->
      let slot = ref None in
      let t = Trigger.create () in
      ivar.state <- Empty ((slot, t) :: waiters);
      Trigger.await t;
      Option.get !slot

let read_evt ivar = Select.Evt {
  try_complete = (fun () ->
    match ivar.state with
    | Filled v -> Some v
    | Empty _ -> None);
  offer = (fun slot trigger ->
    match ivar.state with
    | Empty waiters ->
        ivar.state <- Empty ((slot, trigger) :: waiters)
    | Filled _ -> assert false);
  wrap = Fun.id;
}
