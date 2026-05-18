(** Regression test for issue #8: stale [done_slot] write in
    [Chan.find_live_sender] (and the symmetric write in
    [find_live_receiver]) must not be observable to a select waiter
    that won a different case.

    Scenario reproduced below:
    - Fiber A: select [send_evt ch1 42; recv_evt ch2].  Both
      [try_complete] fail, so A offers both events and awaits the
      shared trigger T.
    - Fiber B: Chan.send ch2 () — wakes T (A's continuation enqueued).
    - Fiber C: Chan.recv ch1 — pops A's stale sender entry, writes
      slot_send := Some (), Trigger.signal returns false (T is spent),
      C blocks.
    - Fiber A resumes.  find_winner scans offered.(0) (send_evt) first;
      before the fix it saw Some () and returned `Sent. *)

open Golike_unicore_select

let () =
  let result = ref `NotDone in
  Sched.run (fun () ->
    let ch1 = Chan.make 0 in
    let ch2 : unit Chan.t = Chan.make 0 in

    Sched.fork (fun () ->
      result := Select.select [
        Select.wrap (fun () -> `Sent)     (Chan.send_evt ch1 42);
        Select.wrap (fun _  -> `Received) (Chan.recv_evt ch2);
      ]
    );

    Sched.fork (fun () -> Chan.send ch2 ());

    Sched.fork (fun () -> ignore (Chan.recv ch1))
  );
  match !result with
  | `Received ->
      Printf.printf "[ PASS ] select_stale_slot — winner = `Received\n%!"
  | `Sent ->
      Printf.printf "[ FAIL ] select_stale_slot — winner = `Sent (stale slot bug)\n%!";
      exit 1
  | `NotDone ->
      Printf.printf "[ FAIL ] select_stale_slot — select never returned\n%!";
      exit 1
