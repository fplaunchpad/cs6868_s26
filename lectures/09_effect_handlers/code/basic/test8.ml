open Effect
open Effect.Deep

type _ Effect.t += E : int t

let _ =
  match perform E with
  | v -> Printf.printf "returned: %d\n" v
  | exception (Invalid_argument msg) ->
      Printf.printf "discontinued with: %s\n" msg
  | effect E, k ->
      discontinue k (Invalid_argument "kapow!")
