open Effect
open Effect.Deep

let perform_some_computation () = Printf.printf "some computation\n"
let perform_more_computation () = Printf.printf "more computation\n"
let handle_foo () = Printf.printf "handled foo\n"

(* Exceptions using built-in exceptions *)
exception Foo

let _ =
  try
    perform_some_computation ();
    raise Foo;           (* <-- raise = perform *)
    perform_more_computation ()
  with
  | Foo -> handle_foo () (* <-- handler; no continuation *)

(* Exceptions using effect handlers *)
type _ Effect.t += Foo' : unit Effect.t

let _ =
  match
    perform_some_computation ();
    perform Foo';         (* <-- perform = raise *)
    perform_more_computation ()
  with
  | _ -> ()
  | effect Foo', _k -> (* <-- handler; drop continuation; leak *)
      handle_foo ()

(* Output:
   some computation
   handled foo
   some computation
   handled foo
*)
