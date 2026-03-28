open Golike_multicore_select

(** Demonstrates why blocking IO inside a fiber is a problem.

    Fiber 1 does a blocking [Unix.read] on a pipe that nobody writes to.
    Fiber 2 tries to print "tick" every scheduling round.

    With [num_domains:1], the single domain thread is stuck in the kernel
    on the [read] syscall, so Fiber 2 never gets to run.  You will see
    "Fiber 1: about to do blocking read..." and then nothing — the program
    hangs.  Press Ctrl-C to kill it.

    Expected output (before hanging):
      Fiber 2: tick 0
      Fiber 1: about to do blocking read (will hang)...
    Only "tick 0" prints (before the read), then silence. *)

let () =
  let rd, _wr = Unix.pipe () in   (* nobody writes to _wr *)
  Sched.run ~num_domains:1 (fun () ->
      (* Fiber 1: blocking read — freezes the OS thread *)
      Sched.fork (fun () ->
          Printf.printf "Fiber 1: about to do blocking read (will hang)...\n%!";
          let buf = Bytes.create 1024 in
          let n = Unix.read rd buf 0 1024 in  (* blocks OS thread! *)
          Printf.printf "Fiber 1: got %d bytes (you won't see this)\n%!" n);
      (* Fiber 2: cooperative ticker — yields between prints *)
      let rec ticker i =
        if i >= 5 then
          Printf.printf "Fiber 2: done (you won't see this either)\n%!"
        else begin
          Printf.printf "Fiber 2: tick %d\n%!" i;
          Sched.yield ();
          ticker (i + 1)
        end
      in
      ticker 0)
