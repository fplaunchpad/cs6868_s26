open Sched_basic

let () =
  run (fun () ->
    fork (fun () ->
      for i = 1 to 3 do
        Printf.printf "Task A: %d\n" i;
        yield ()
      done);
    fork (fun () ->
      for i = 1 to 3 do
        Printf.printf "Task B: %d\n" i;
        yield ()
      done);
    for i = 1 to 3 do
      Printf.printf "Main  : %d\n" i;
      yield ()
    done)

(* Output:
   Task A: 1
   Task B: 1
   Task A: 2
   Main  : 1
   Task B: 2
   Task A: 3
   Main  : 2
   Task B: 3
   Main  : 3
*)
