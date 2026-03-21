open Effect

type _ Effect.t += Fork : (unit -> unit) -> unit Effect.t
type _ Effect.t += Yield : unit Effect.t

let fork f = perform (Fork f)
let yield () = perform Yield

let run main =
  let run_q = Queue.create () in
  let enqueue k = Queue.push k run_q in
  let dequeue () =
    if Queue.is_empty run_q then ()
    else Effect.Deep.continue (Queue.pop run_q) ()
  in
  let rec spawn f =
    match f () with
    | () -> dequeue ()
    | exception e ->
        Printf.eprintf "Uncaught exception: %s\n" (Printexc.to_string e);
        dequeue ()
    | effect (Fork f), k ->
        enqueue k;
        spawn f
    | effect Yield, k ->
        enqueue k;
        dequeue ()
    | effect (Trigger.Await trigger), k ->
        if Trigger.on_signal trigger (fun () -> enqueue k) then
          dequeue ()
        else
          (* Already signaled — resume immediately; impossible in uniprocessor
             mode *)
          Effect.Deep.continue k ()
  in
  spawn main
