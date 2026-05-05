(* Lecture 11: Portability, Contention, and Data-Race Freedom
   ===========================================================

   OxCaml prevents data races at compile time using two mode axes:

   Portability: can a function cross domain boundaries?
   - portable:    yes, safe to run on any domain
   - nonportable: no, captures thread-local mutable state

   Contention: has a value been shared across domains?
   - uncontended: single-domain access
   - shared:      read-only multi-domain access
   - contended:   writable multi-domain access

   Key rule: a closure that captures uncontended mutable state is
   nonportable. fork_join2 requires portable functions. Therefore,
   the type system prevents sharing mutable state across domains
   without explicit synchronization.
*)

(* --- 1. Pure functions are portable --- *)

let add x y = x + y

let parallel_add par =
  let #(a, b) =
    Parallel.fork_join2 par
      (fun _par -> add 10 20)
      (fun _par -> add 30 40)
  in
  Printf.printf "parallel_add: %d + %d = %d\n" a b (a + b)

(* --- 2. Capturing a ref makes a closure nonportable --- *)

(* This compiles — single-threaded use of a ref is fine *)
let sequential_counter () =
  let counter = ref 0 in
  for _ = 1 to 10 do
    incr counter
  done;
  Printf.printf "sequential counter: %d\n" !counter

(* This does NOT compile — the closure captures `counter` (uncontended ref),
   making it nonportable, but fork_join2 requires portable functions.

   let bad_parallel_counter par =
     let counter = ref 0 in
     let #((), ()) =
       Parallel.fork_join2 par
         (fun _par -> for _ = 1 to 5 do incr counter done)
         (fun _par -> for _ = 1 to 5 do incr counter done)
     in
     Printf.printf "counter: %d\n" !counter

   Error: This value is nonportable because it captures a ref,
   but fork_join2 expects a portable function.
*)

(* --- 3. The fix: use Atomic for shared counters --- *)

let safe_parallel_counter par =
  let counter = Atomic.make 0 in
  let #((), ()) =
    Parallel.fork_join2 par
      (fun _par -> for _ = 1 to 1000 do Atomic.incr counter done)
      (fun _par -> for _ = 1 to 1000 do Atomic.incr counter done)
  in
  Printf.printf "atomic counter: %d\n" (Atomic.get counter)

(* --- 4. Independent computation on disjoint data --- *)

let parallel_compute par =
  let #(sum_left, sum_right) =
    Parallel.fork_join2 par
      (fun _par ->
        let s = ref 0 in
        for i = 0 to 499 do s := !s + i done;
        !s)
      (fun _par ->
        let s = ref 0 in
        for i = 500 to 999 do s := !s + i done;
        !s)
  in
  Printf.printf "parallel sum: %d + %d = %d\n"
    sum_left sum_right (sum_left + sum_right)

(* --- 5. Nested fork-join --- *)

let rec parallel_sum par lo hi =
  if hi - lo <= 100 then
    let mutable s = 0 in
    for i = lo to hi - 1 do s <- s + i done;
    s
  else
    let mid = lo + (hi - lo) / 2 in
    let #(left, right) =
      Parallel.fork_join2 par
        (fun par -> parallel_sum par lo mid)
        (fun par -> parallel_sum par mid hi)
    in
    left + right

let demonstrate_nested par =
  let total = parallel_sum par 0 1000 in
  Printf.printf "nested fork-join sum 0..999: %d\n" total

(* --- Runner --- *)

let run_parallel ~f =
  let module Scheduler = Parallel_scheduler in
  let scheduler = Scheduler.create () in
  let result = Scheduler.parallel scheduler ~f in
  Scheduler.stop scheduler;
  result

let () =
  sequential_counter ();
  run_parallel ~f:parallel_add;
  run_parallel ~f:safe_parallel_counter;
  run_parallel ~f:parallel_compute;
  run_parallel ~f:demonstrate_nested
