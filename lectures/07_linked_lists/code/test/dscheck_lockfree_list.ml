(** DSCheck tests for Lock-Free List *)

module Atomic = Dscheck.TracedAtomic
module L = Lockfree_list

(*
  TEST1:
    Concurrent threads trying to push same ele, but becuase we can't have 
    duplicates only one should succeed
*)
let two_adds_same_element () =
  Atomic.trace (fun () ->
    let l  = L.create () in
    (* We will be using two flags r1, r2 to see which thread succedds in pushing value.  *)
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in

    Atomic.spawn (fun () -> Atomic.set r1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set r2 (L.add l 1));

    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let a = Atomic.get r1 in

        (* This says only one of them should be true, 
        bothof them can't be true at same time and lists should contain value 1 *)
        let b = Atomic.get r2 in (a || b) && not (a && b) && L.contains l 1 
      )))

(* TEST 2:
        Two concurrent adds of diff elements.
        Both should succedd and both values should be present insidelist. 
       *)

let two_adds_distinct_elements () =
  Atomic.trace (fun () ->
    let l  = L.create () in
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in

    Atomic.spawn (fun () -> Atomic.set r1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set r2 (L.add l 2));

    (* The final goal is to check: Both were successful in pushing values, meaning r1 and r2 should be true 
    and lists should contain both values as well *)
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        Atomic.get r1 && Atomic.get r2  && L.contains l 1  && L.contains l 2
      )))


(* 
TEST 3:
    Two concurrent removes of the same element, 
    Both threads will try to delete it, succedding only one. 
*)

let two_removes_same_element () =
  Atomic.trace (fun () ->
    let l  = L.create () in
    ignore (L.add l 42);   (* setup: 42 already in the list *)
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in

    Atomic.spawn (fun () -> Atomic.set r1 (L.remove l 42));
    Atomic.spawn (fun () -> Atomic.set r2 (L.remove l 42));

    (* Final goal here is to check only one thread should get success only calling deletion more than once,
    as we dont have duplicates in our list. Also after either of the thread get success, the lists should not contain 
    that value. *)
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let a = Atomic.get r1 in
        let b = Atomic.get r2 in (a || b) && not (a && b) && not (L.contains l 42)
      )))

(* Test 4: 
  Add and remove racing on the same element (empty start)    
                                                                    
   Two valid linearizations:                                          
   remove first --> remove=false, add=true,  contains=true          
   add first    --> add=true,     remove=true, contains=false       
  add=false is always a bug — nothing blocked it on an empty list.   
*)

let add_remove_race () =
  Atomic.trace (fun () ->
    let l     = L.create () in
    let r_add = Atomic.make false in
    let r_rem = Atomic.make false in

    Atomic.spawn (fun () -> Atomic.set r_add (L.add l 42));
    Atomic.spawn (fun () -> Atomic.set r_rem (L.remove l 42));

    Atomic.final (fun () ->
      Atomic.check (fun () ->
        match Atomic.get r_add, Atomic.get r_rem with
        | true, false ->
            (* remove ran first (element absent), add won after *)
            L.contains l 42
        | true, true ->
            (* add ran first, then remove succeeded *)
            not (L.contains l 42)
        | false, _ ->
            (* add can never fail on an empty list — always a bug *)
            false
      )))

(* ------------------------------------------------------------------ *)
(* Test 5: Conservation — no elements created or lost                  *)
(*                                                                      *)
(* 4 threads: add 1, add 2, remove 1, remove 2.                      *)
(* For each element: if added and removed --> gone.                     *)
(*                   if added only         --> present.                 *)
(*                   if never added        --> remove must have returned false *)
(* ------------------------------------------------------------------ *)

let conservation () =
  Atomic.trace (fun () ->
    let l   = L.create () in
    let ra1 = Atomic.make false in   (* result: add 1    *)
    let ra2 = Atomic.make false in   (* result: add 2    *)
    let rr1 = Atomic.make false in   (* result: remove 1 *)
    let rr2 = Atomic.make false in   (* result: remove 2 *)

    Atomic.spawn (fun () -> Atomic.set ra1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set ra2 (L.add l 2));
    Atomic.spawn (fun () -> Atomic.set rr1 (L.remove l 1));
    Atomic.spawn (fun () -> Atomic.set rr2 (L.remove l 2));

    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let check x added removed =
          if added && removed then not (L.contains l x)
          else if added        then L.contains l x
          else                      not removed
        in
        check 1 (Atomic.get ra1) (Atomic.get rr1)
        && check 2 (Atomic.get ra2) (Atomic.get rr2)
      )))

(* Removed alcotest, and now directly calling each fn and verifying it  *)
let () =
(* If each test case runs successfully means it was successfull.  *)
  two_adds_same_element ();
  print_endline "no-duplicates test passed!";

  two_adds_distinct_elements ();
  print_endline "no-lost-adds test passed!";

  two_removes_same_element ();
  print_endline "excl-remove test passed!";

  add_remove_race ();
  print_endline "add-rem-race test passed!";

  conservation ();
  print_endline "conservation test passed!";

  print_endline "All dscheck_lockfree_list tests passed!"


  