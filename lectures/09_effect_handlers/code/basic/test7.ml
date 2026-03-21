open Effect
open Effect.Deep

type _ Effect.t += E : unit t

let _ =
  try perform E with
  | effect E, k ->
    continue k ();
    continue k () (* Will raise exception *)
