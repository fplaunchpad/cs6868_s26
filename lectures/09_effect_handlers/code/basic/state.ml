open Effect
open Effect.Deep

module State (T : sig type t end) : sig
  val get : unit -> T.t
  val set : T.t -> unit
  val run : T.t -> (unit -> 'a) -> T.t * 'a
end = struct
  type _ Effect.t += Get : T.t Effect.t
  type _ Effect.t += Set : T.t -> unit Effect.t
  let get () = perform Get
  let set v = perform (Set v)
  let run (init : T.t) f =
    let state = ref init in
    let res =
      try f () with
      | effect Get, k -> continue k !state
      | effect (Set v), k -> state := v; continue k ()
    in
    (!state, res)
end

module IS = State (struct type t = int end)

let comp () =
  Printf.printf "initial: %d\n" (IS.get ());
  IS.set 42;
  Printf.printf "after set: %d\n" (IS.get ());
  IS.set 100;
  Printf.printf "after second set: %d\n" (IS.get ())

let () =
  let final_state, () = IS.run 0 comp in
  Printf.printf "final state: %d\n" final_state

(* Output:
   initial: 0
   after set: 42
   after second set: 100
   final state: 100
*)

(* State-passing style: purely functional, no mutation *)
module StateFn (T : sig type t end) : sig
  val get : unit -> T.t
  val set : T.t -> unit
  val run : T.t -> (unit -> 'a) -> T.t * 'a
end = struct
  type _ Effect.t += Get : T.t Effect.t
  type _ Effect.t += Set : T.t -> unit Effect.t
  let get () = perform Get
  let set v = perform (Set v)
  let run (init : T.t) f =
    let handler =
      match f () with
      | x -> (fun s -> (s, x))
      | effect Get, k ->
          (fun (s : T.t) -> (continue k s) s)
      | effect (Set v), k ->
          (fun _s -> (continue k ()) v)
    in
    handler init
end

module ISFn = StateFn (struct type t = int end)

let comp2 () =
  Printf.printf "initial: %d\n" (ISFn.get ());
  ISFn.set 42;
  Printf.printf "after set: %d\n" (ISFn.get ());
  ISFn.set 100;
  Printf.printf "after second set: %d\n" (ISFn.get ())

let () =
  let final_state, () = ISFn.run 0 comp2 in
  Printf.printf "final state: %d\n" final_state

(* Output:
   initial: 0
   after set: 42
   after second set: 100
   final state: 100
*)


let () =
    let final_state, value  = ISFn.run 0 (fun () ->
                            let x = ISFn.get () in
                            ISFn.set (x + 1);
                            ISFn.get ()) in
   Printf.printf "***************************\n";
   Printf.printf "final state: %d\n" final_state;
   Printf.printf "value : %d\n" value
