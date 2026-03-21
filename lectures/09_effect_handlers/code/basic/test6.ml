open Effect
open Effect.Deep

type _ Effect.t += E : unit t
                 | F : unit t

let f () =
  try perform E with
  | Unhandled E -> Printf.printf "Caught Unhandled E\n"

let g () =
  match f () with
  | x -> x
  | effect F, k ->
      continue k ()

let _ = g ()
