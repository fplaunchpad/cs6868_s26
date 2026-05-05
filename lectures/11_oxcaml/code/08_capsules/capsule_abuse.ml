(* Lecture 11: Capsule abuse attempts the API refuses.
   ====================================================
   Three escape hatches one might try, and what the type checker
   says about each. The file compiles; the rejected attempts are
   kept in block comments with the verbatim error.                       *)

open Await

(* ============================================================ *)
(* §1  Can I leak a direct reference to the inner ref?           *)
(* ============================================================ *)
(* The WRITE compiles — we stash the unwrapped ref into a top-level
   atomic. But the type system poisons the leaked value: anything
   inside a Portable.Atomic is "contended", and dereferencing a ref
   on a contended value is rejected. So the alias is reachable but
   useless without going back through the lock.                          *)

let leaked : int ref option Portable.Atomic.t = Portable.Atomic.make None

let leaky_gensym =
  let (P mutex) = Await_capsule.Mutex.create () in
  let counter = Capsule.Data.create (fun () -> ref 0) in
  fun (w : Await.t) ->
    Await_capsule.Mutex.with_lock w mutex ~f:(fun access ->
      let c = Capsule.Data.unwrap ~access counter in
      Portable.Atomic.set leaked (Some c);   (* write compiles *)
      incr c;
      !c)

(* let try_read_leak () =
     match Portable.Atomic.get leaked with
     | None -> 0
     | Some c -> !c

   Error: This value is "contended"
          because it is contained (via constructor "Some") in the value
          which is "contended".
          However, the highlighted expression is expected to be
          "uncontended".                                                 *)


(* ============================================================ *)
(* §2  Can one mutex protect several Capsule.Data.t?             *)
(* ============================================================ *)
(* Yes — and this is genuinely safe. It is the moral equivalent of one
   mutex guarding two fields of a struct: holding the lock excludes
   every other accessor of either field. The brand on the access token
   matches both data values, so a single critical section can read or
   write both.                                                           *)

let one_mutex_two_data (w : Await.t) =
  let (P mutex) = Await_capsule.Mutex.create () in
  let a = Capsule.Data.create (fun () -> ref 0) in
  let b = Capsule.Data.create (fun () -> ref 100) in
  Await_capsule.Mutex.with_lock w mutex ~f:(fun access ->
    let ra = Capsule.Data.unwrap ~access a in
    let rb = Capsule.Data.unwrap ~access b in
    incr ra;
    incr rb;
    (!ra, !rb))


(* ============================================================ *)
(* §3  Can the SAME Capsule.Data.t be unlocked by TWO mutexes?   *)
(* ============================================================ *)
(* No — and this is the case that would actually be unsound (thread
   holding mutex A and thread holding mutex B could enter critical
   sections simultaneously). The brand system makes it impossible:
   `Capsule.Mutex.create` introduces a fresh existential brand $k via
   the `P` pattern; once `data` is first unwrapped under mutex A, its
   type is fixed at brand $k, and a second unwrap under mutex B's
   brand $k1 cannot unify.                                                *)

(* let two_mutexes_one_data (w : Await.t) =
     let (P mutex_a) = Await_capsule.Mutex.create () in
     let (P mutex_b) = Await_capsule.Mutex.create () in
     let data = Capsule.Data.create (fun () -> ref 0) in
     let r1 =
       Await_capsule.Mutex.with_lock w mutex_a ~f:(fun access ->
         let r = Capsule.Data.unwrap ~access data in
         incr r; !r)
     in
     let r2 =
       Await_capsule.Mutex.with_lock w mutex_b ~f:(fun access ->
         let r = Capsule.Data.unwrap ~access data in
         incr r; !r)
     in
     (r1, r2)

   Error: This expression has type "(int ref, $k) Capsule_expert.Data.t"
          but an expression was expected of type
            "(int ref, $k1) Capsule_expert.Data.t"
          Type "$k" is not compatible with type "$k1"
          Hint: "$k" and "$k1" are existential types bound by the
                constructor "P".                                         *)


(* ============================================================ *)
(* Driver                                                        *)
(* ============================================================ *)

let demo par =
  let #(n, (a, b)) =
    Parallel.fork_join2 par
      (fun _par ->
        let w = Await_blocking.await Terminator.never in
        leaky_gensym w)
      (fun _par ->
        let w = Await_blocking.await Terminator.never in
        one_mutex_two_data w)
  in
  Printf.printf "leaky_gensym call         : counter = %d\n" n;
  Printf.printf "one_mutex_two_data        : a = %d, b = %d\n" a b

let run_parallel ~f =
  let module Scheduler = Parallel_scheduler in
  let scheduler = Scheduler.create () in
  let result = Scheduler.parallel scheduler ~f in
  Scheduler.stop scheduler;
  result

let () = run_parallel ~f:demo
