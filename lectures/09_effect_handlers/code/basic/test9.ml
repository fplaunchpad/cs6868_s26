open Effect
open Effect.Deep

type _ Effect.t += Ask : string t

let greeting () =
  let name = perform Ask in
  Printf.printf "Hello, %s!\n" name;
  if name = "Bob" then failwith "Bob is not welcome"

(* Way 1: try..with -- handles effects and exceptions.
   The return value of the body is the return value of the whole expression. *)
let _ =
  Printf.printf "--- try..with ---\n";
  try greeting () with
  | effect Ask, k -> continue k "Alice"
  | Failure msg -> Printf.printf "caught exception: %s\n" msg

(* Way 2: match..with -- handles effects, exceptions, AND the return value.
   This gives you a chance to transform or inspect what the body returned. *)
let _ =
  Printf.printf "--- match..with ---\n";
  match greeting () with
  | () -> Printf.printf "greeting returned normally\n"
  | exception (Failure msg) ->
      Printf.printf "caught exception: %s\n" msg
  | effect Ask, k -> continue k "Bob"
