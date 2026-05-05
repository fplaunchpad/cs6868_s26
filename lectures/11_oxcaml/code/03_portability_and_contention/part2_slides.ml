(* ==========================================================================
   Part 2: Modes and Data-Race Freedom — slide snippets
   ==========================================================================
   Copy-paste targets for slides. Each block is a self-contained fragment
   from the handout. Error messages are shown as block comments under the
   offending snippet.
   ========================================================================== *)


(* --- §1  Contention: types --------------------------------------------- *)

type mood = Happy | Neutral | Sad

type thing = { price : float; mutable mood : mood }


(* --- §2  Reading an immutable field is fine even when contended -------- *)

let price_contended (t @ contended) = t.price
(* val price_contended : thing @ contended -> float = <fun> *)


(* --- §3  Writing a mutable field on a contended value: REJECTED -------- *)

let cheer_up_contended (t @ contended) = t.mood <- Happy
(*
Error: This value is contended but is expected to be uncontended
       because its mutable field mood is being written.
*)


(* --- §4  Even READING a mutable field on a contended value: REJECTED --- *)

let read_mood_contended (t @ contended) = t.mood
(*
Error: This value is contended but is expected to be shared or uncontended
       because its mutable field mood is being read.
*)


(* --- §5  No annotation = uncontended = ordinary OCaml ------------------ *)

let cheer_up t = t.mood <- Happy
(* val cheer_up : thing -> unit = <fun> *)

let read_mood t = t.mood
(* val read_mood : thing -> mood = <fun> *)


(* --- §6  Portability: pure function is portable ------------------------ *)

let test_portable () =
  let (f @ portable) = fun x y -> x + y in
  f 1 2
(* val test_portable : unit -> int = <fun>
   test_portable ()  =>  3                                         *)


(* --- §7  Capturing a mutable ref makes a closure nonportable ----------- *)

let test_nonportable () =
  let r = ref 0 in
  let (counter @ portable) () = incr r; !r in
  counter ()
(*
Error: This value is nonportable
       because it contains a usage (of the value r ...)
       which is expected to be uncontended.
       However, the highlighted expression is expected to be portable.
*)


(* --- §8  The data-race scenario the mode system rules out -------------- *)
(*
   Domain 1                    Domain 2
   ────────                    ────────
   t.mood <- Happy             t.mood <- Sad      ← DATA RACE!

   Portability: closures crossing a domain boundary must be portable
                ⇒ their captures are treated as contended
   Contention:  contended mutable fields cannot be read or written
                ⇒ the write above is statically rejected
*)


(* --- §9  Captured values vs parameters --------------------------------- *)
(* `loop` is portable: it doesn't CAPTURE `a` from the outer scope.
   `a` is passed as a PARAMETER annotated @ uncontended, so it can still
   be mutated. Portability restricts captures only.                       *)

let factorial_portable n =
  let a = ref 1 in
  let rec (loop @ portable) (a @ uncontended) i =
    if i > 0 then begin
      a := !a * i;
      loop a (i - 1)
    end
  in
  loop a n;
  !a
(* val factorial_portable : int -> int = <fun>
   factorial_portable 10  =>  3628800                              *)


(* --- §10  First working parallel program: gensym, fixed ---------------- *)
(* Same gensym from the opener, now top-level AND portable. The trick is
   Portable.Atomic.t — it mode-crosses BOTH contention AND portability,
   so a closure capturing it can be marked @ portable. The spawn and the
   main-domain call both happen at the top level.                          *)

[@@@alert "-do_not_spawn_domains"]

open Portable


let gensym =
  let count = Atomic.make 0 in
  let res @ portable = fun prefix ->
    let n = Atomic.fetch_and_add count 1 in
    prefix ^ "_" ^ string_of_int n
  in
  res

let d = Domain.Safe.spawn (fun () -> gensym "y")
let s1 = gensym "x"
let s2 = Domain.join d
let () = Printf.printf "%s %s\n" s1 s2
(* prints:  x_0 y_1                                                *)
