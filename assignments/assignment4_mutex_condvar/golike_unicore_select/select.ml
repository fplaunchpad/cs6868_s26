(** CML-style events for composable synchronous communication.

    Any synchronisation primitive (channels, IVars, …) can create events.
    {!select} waits for the first of several events to occur.

    A single shared {!Trigger.t} is used across all cases: the first
    counterpart to signal it wins; others see {!Trigger.signal} return
    [false] and skip the stale waiter. *)

type 'b event = Evt : {
  try_complete : unit -> 'a option;
  offer : 'a option ref -> Trigger.t -> unit;
  wrap : 'a -> 'b;
} -> 'b event

let wrap f (Evt r) = Evt {
  try_complete = r.try_complete;
  offer = r.offer;
  wrap = (fun x -> f (r.wrap x));
}

(* Per-case state after the offer phase. *)
type 'b offered = Offered : {
  slot : 'a option ref;
  wrap : 'a -> 'b;
} -> 'b offered

let select events =
  let events = Array.of_list events in
  let n = Array.length events in
  if n = 0 then invalid_arg "Select.select: empty case list";

  (* Phase 1 — scan for an immediately ready case *)
  let rec scan i =
    if i >= n then None
    else
      let (Evt { try_complete; wrap; _ }) = events.(i) in
      match try_complete () with
      | Some v -> Some (wrap v)
      | None -> scan (i + 1)
  in
  match scan 0 with
  | Some result -> result
  | None ->
      (* Phase 2 — create one shared trigger, offer all cases *)
      let trigger = Trigger.create () in
      let offered = Array.init n (fun i ->
        let (Evt { offer; wrap; _ }) = events.(i) in
        let slot = ref None in
        offer slot trigger;
        Offered { slot; wrap }
      ) in

      (* Phase 3 — block until one counterpart signals the trigger *)
      Trigger.await trigger;

      (* Phase 4 — find the winning case *)
      let rec find_winner i =
        if i >= n then failwith "Select: bug — no winner found"
        else
          let (Offered { slot; wrap }) = offered.(i) in
          match !slot with
          | Some v -> wrap v
          | None -> find_winner (i + 1)
      in
      find_winner 0
