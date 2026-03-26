open Golike_multicore_select

(** Build a [Select.event] that fires after [delay] seconds.
    The channel is buffered (capacity 1) so the timer fiber can always
    complete its [Chan.send] even if nobody ever receives — no leak. *)
let timeout_evt delay =
  let ch = Chan.make 1 in
  Sched.fork (fun () -> Io.sleep delay; Chan.send ch ());
  Chan.recvEvt ch

(** Sender: sends integers 0..n-1 on [ch], one per second, then stops. *)
let sender ch n =
  for i = 0 to n - 1 do
    Io.sleep 1.0;
    Chan.send ch i;
  done;
  Printf.printf "[sender] done\n%!"

(** Receiver: keeps trying until it has received [n] messages, printing
    "msg <v>" on each successful receive and "timeout" on each 0.5 s
    timeout.  Both sender and receiver terminate after exactly [n]
    messages, so the scheduler can exit cleanly. *)
let receiver ch n =
  let received = ref 0 in
  while !received < n do
    (match
      Select.select
        [ Chan.recvEvt ch   |> Select.wrap (fun v  -> `Msg v)
        ; timeout_evt 0.5   |> Select.wrap (fun () -> `Timeout)
        ]
    with
    | `Msg v  -> Printf.printf "[receiver] msg %d\n%!" v; incr received
    | `Timeout -> Printf.printf "[receiver] timeout\n%!");
  done;
  Printf.printf "[receiver] done\n%!"

let () =
  let n = 100 in
  Sched.run ~num_domains:4 (fun () ->
      let ch = Chan.make 0 in
      Sched.fork (fun () -> sender ch n);
      receiver ch n)
