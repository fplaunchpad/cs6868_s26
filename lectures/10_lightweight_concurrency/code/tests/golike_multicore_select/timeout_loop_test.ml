open Golike_multicore_select

(** Simplest possible looping-timeout test.
    No message channel — just a single timeout event per iteration.
    If this deadlocks, the bug is in the timer/select plumbing itself. *)

let timeout_evt delay =
  let ch = Chan.make 1 in
  Sched.fork (fun () -> Io.sleep delay; Chan.send ch ());
  Chan.recvEvt ch

let () =
  let n = 20 in
  Sched.run ~num_domains:4 (fun () ->
    for i = 1 to n do
      Printf.printf "[iter %d/%d] selecting on timeout ...\n%!" i n;
      Select.select
        [ timeout_evt 0.05 |> Select.wrap (fun () -> ()) ];
      Printf.printf "[iter %d/%d] timeout fired\n%!" i n
    done;
    Printf.printf "timeout_loop_test: PASSED (%d iterations)\n%!" n)
