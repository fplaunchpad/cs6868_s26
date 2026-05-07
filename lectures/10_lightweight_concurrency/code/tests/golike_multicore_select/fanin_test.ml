open Golike_multicore_select

(* Fan-in with select. Two senders on rendezvous channels, one
   receiver using select. Each rendezvous send is matched 1:1 with a
   recv inside select, so the receiver always observes exactly the
   six values sent (sum = 660), regardless of how the four domains
   interleave. *)
let () =
  Printf.printf "=== Select fan-in ===\n";
  Sched.run ~num_domains:4 (fun () ->
    let ch1 = Chan.make 0 in
    let ch2 = Chan.make 0 in
    let total = Atomic.make 0 in
    Sched.fork (fun () ->
      for i = 1 to 3 do
        Chan.send ch1 (i * 10)
      done
    );
    Sched.fork (fun () ->
      for i = 1 to 3 do
        Chan.send ch2 (i * 100)
      done
    );
    for _ = 1 to 6 do
      let v = Select.select [
        Chan.recv_evt ch1;
        Chan.recv_evt ch2;
      ] in
      ignore (Atomic.fetch_and_add total v : int)
    done;
    Printf.printf "  Total: %d\n" (Atomic.get total);
    assert (Atomic.get total = 10 + 20 + 30 + 100 + 200 + 300)
  );
  Printf.printf "  PASSED\n"
