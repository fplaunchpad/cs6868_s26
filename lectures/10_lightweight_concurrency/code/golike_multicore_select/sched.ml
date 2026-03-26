open Effect

type _ Effect.t += Fork : (unit -> unit) -> unit Effect.t
type _ Effect.t += Yield : unit Effect.t

let fork f = perform (Fork f)
let yield () = perform Yield

let run ?(num_domains = Domain.recommended_domain_count ()) main =
  (* ---- shared work queue (producer-consumer monitor) ---- *)
  let q : (unit, unit) Deep.continuation Queue.t = Queue.create () in
  let mutex = Mutex.create () in
  let cond = Condition.create () in

  (* Number of active fibers: incremented at fork, decremented when a
     fiber's handler returns (normal completion or exception).
     A fiber blocked on Trigger.Await is still "active". *)
  let active_fibers = Atomic.make 1 in (* main counts as one *)

  let enqueue k =
    Mutex.lock mutex;
    Queue.push k q;
    Condition.signal cond;
    Mutex.unlock mutex
  in

  let dequeue () =
    Mutex.lock mutex;
    let rec wait () =
      if not (Queue.is_empty q) then begin
        let k = Queue.pop q in
        Mutex.unlock mutex;
        Some k
      end else if Atomic.get active_fibers <= 0 then begin
        (* All fibers done — wake other workers so they can exit too *)
        Condition.broadcast cond;
        Mutex.unlock mutex;
        None
      end else begin
        Condition.wait cond mutex;
        wait ()
      end
    in
    wait ()
  in

  let fiber_done () =
    if Atomic.fetch_and_add active_fibers (-1) = 1 then begin
      (* Last fiber completed — wake all waiting workers *)
      Mutex.lock mutex;
      Condition.broadcast cond;
      Mutex.unlock mutex
    end
  in

  (* ---- per-domain effect handler ---- *)

  let rec spawn f =
    match f () with
    | () -> fiber_done ()
    | exception e ->
        Printf.eprintf "Uncaught exception: %s\n" (Printexc.to_string e);
        fiber_done ()
    | effect (Fork f), k ->
        Atomic.incr active_fibers;
        enqueue k;
        spawn f
    | effect Yield, k ->
        enqueue k
    | effect (Trigger.Await trigger), k ->
        if Trigger.on_signal trigger (fun () -> enqueue k) then
          ()
        else
          Deep.continue k ()

  and worker () =
    match dequeue () with
    | None -> ()
    | Some k -> Deep.continue k (); worker ()
  in

  (* Spawn worker domains (num_domains - 1 extra; this domain also works) *)
  let n_workers = max 0 (num_domains - 1) in
  let domains = List.init n_workers (fun _ -> Domain.spawn worker) in

  (* Run main fiber on the current domain, then become a worker *)
  spawn main;
  worker ();

  (* Wait for all worker domains *)
  List.iter Domain.join domains
