open Golike_unicore

(* Test 1: Basic fill and read *)
let () =
  Printf.printf "=== IVar: fill then read ===\n";
  Sched.run (fun () ->
    let iv = Ivar.create () in
    Ivar.fill iv 42;
    let v = Ivar.read iv in
    Printf.printf "  Got: %d\n" v
  )
(* Output:
   === IVar: fill then read ===
     Got: 42
*)

(* Test 2: Read blocks until fill *)
let () =
  Printf.printf "\n=== IVar: read blocks until fill ===\n";
  Sched.run (fun () ->
    let iv = Ivar.create () in
    Sched.fork (fun () ->
      Printf.printf "  Reader waiting...\n";
      let v = Ivar.read iv in
      Printf.printf "  Reader got: %d\n" v
    );
    Printf.printf "  Filling with 99\n";
    Ivar.fill iv 99
  )
(* Output:
   === IVar: read blocks until fill ===
     Reader waiting...
     Filling with 99
     Reader got: 99
*)

(* Test 3: Multiple readers wake on fill *)
let () =
  Printf.printf "\n=== IVar: multiple readers ===\n";
  Sched.run (fun () ->
    let iv = Ivar.create () in
    for i = 1 to 3 do
      Sched.fork (fun () ->
        let v = Ivar.read iv in
        Printf.printf "  Reader %d got: %d\n" i v
      )
    done;
    Sched.yield ();
    Printf.printf "  Filling with 7\n";
    Ivar.fill iv 7
  )
(* Output:
   === IVar: multiple readers ===
     Filling with 7
     Reader 3 got: 7
     Reader 2 got: 7
     Reader 1 got: 7
*)

(* Test 4: Read after fill returns immediately *)
let () =
  Printf.printf "\n=== IVar: read after fill (no blocking) ===\n";
  Sched.run (fun () ->
    let iv = Ivar.create () in
    Ivar.fill iv "already here";
    let v1 = Ivar.read iv in
    let v2 = Ivar.read iv in
    Printf.printf "  Read 1: %s\n" v1;
    Printf.printf "  Read 2: %s\n" v2
  )
(* Output:
   === IVar: read after fill (no blocking) ===
     Read 1: already here
     Read 2: already here
*)

(* Test 5: Double fill raises *)
let () =
  Printf.printf "\n=== IVar: double fill raises ===\n";
  Sched.run (fun () ->
    let iv = Ivar.create () in
    Ivar.fill iv 1;
    (try Ivar.fill iv 2
     with Failure msg -> Printf.printf "  Caught: %s\n" msg)
  )
(* Output:
   === IVar: double fill raises ===
     Caught: IVar.fill: already filled
*)

(* Test 6: Deadlock — read on never-filled IVar silently exits *)
let () =
  Printf.printf "\n=== IVar: deadlock (silent exit) ===\n";
  Sched.run @@ fun () ->
    let iv = Ivar.create () in
    Ivar.read iv |> ignore;
    Printf.printf "  This should never print\n"
(* Output:
   === IVar: deadlock (silent exit) ===
   (nothing — scheduler exits silently when all fibers are blocked)
*)
