open Golike_unicore

(* Test 1: Basic async/await *)
let () =
  Printf.printf "=== Basic async/await ===\n";
  Sched.run (fun () ->
    let p = Promise.async (fun () ->
      Printf.printf "  Computing...\n";
      Sched.yield ();
      42
    ) in
    Printf.printf "  Doing other work...\n";
    let v = Promise.await p in
    Printf.printf "  Got: %d\n" v
  )

(* Test 2: Multiple awaiters on the same promise *)
let () =
  Printf.printf "\n=== Multiple awaiters ===\n";
  Sched.run (fun () ->
    let p = Promise.async (fun () ->
      Sched.yield ();
      "hello"
    ) in
    Sched.fork (fun () ->
      let v = Promise.await p in
      Printf.printf "  Fiber A got: %s\n" v
    );
    Sched.fork (fun () ->
      let v = Promise.await p in
      Printf.printf "  Fiber B got: %s\n" v
    );
    let v = Promise.await p in
    Printf.printf "  Main got: %s\n" v
  )

(* Test 3: Parallel Fibonacci with async/await *)
let () =
  Printf.printf "\n=== Fibonacci (async/await) ===\n";
  Sched.run (fun () ->
    let rec fib n =
      if n <= 1 then n
      else
        let a = Promise.async (fun () -> fib (n - 1)) in
        let b = fib (n - 2) in
        Promise.await a + b
    in
    for i = 0 to 10 do
      Printf.printf "  fib(%d) = %d\n" i (fib i)
    done
  )
