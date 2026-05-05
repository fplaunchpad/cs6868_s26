(* Lecture 11: gensym, capsule version
   ===================================== *)

open Await

let gensym =
  (* `P mutex` introduces a fresh existential brand $k tied to this mutex.
     Anything we want this mutex to protect must end up branded with $k,
     and the only way to obtain a $k-branded `access` token is to call
     with_lock on this very mutex. *)
  let (P mutex) = Await_capsule.Mutex.create () in
  (* The ref is created INSIDE Capsule.Data.create — it has no name in
     scope outside, so the only handle to it is `counter`, which is
     branded $k. The bare `ref` cannot be aliased out. *)
  let counter = Capsule.Data.create (fun () -> ref 0) in
  let fetch_and_incr (w : Await.t) =
    (* with_lock acquires the mutex and hands the body an `access`
       token branded $k. `w : Await.t` is the awaiter — needed because
       acquiring the lock may suspend the fiber. *)
    Await_capsule.Mutex.with_lock w mutex
      ~f:(fun access ->
        (* Capsule.Data.unwrap requires a brand-matching access token.
           Outside this body, no $k token exists, so no one can reach `c`. *)
        let c = Capsule.Data.unwrap ~access counter in
        incr c;
        !c)
  in
  fun w prefix -> prefix ^ "_" ^ Int.to_string (fetch_and_incr w)

let gensym_pair par =
  let #(s1, s2) =
    Parallel.fork_join2 par
      (fun _par ->
        let w = Await_blocking.await Terminator.never in
        gensym w "x")
      (fun _par ->
        let w = Await_blocking.await Terminator.never in
        gensym w "y")
  in
  Printf.printf "gensym_pair: %s %s\n" s1 s2;
  assert (s1 <> s2)

let run_parallel ~f =
  let module Scheduler = Parallel_scheduler in
  let scheduler = Scheduler.create () in
  let result = Scheduler.parallel scheduler ~f in
  Scheduler.stop scheduler;
  result

let () = run_parallel ~f:gensym_pair
