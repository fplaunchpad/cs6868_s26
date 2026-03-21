open Effect
open Effect.Deep

module Reader (T : sig type t end) : sig
  val get : unit -> T.t
  val run : T.t -> (unit -> 'a) -> 'a
end = struct
  type _ Effect.t += Get : T.t Effect.t
  let get () = perform Get
  let run (env : T.t) f =
    match f () with
    | x -> x
    | effect Get, k -> continue k env
end

module Inner = Reader (struct type t = int end)
module Outer = Reader (struct type t = int end)

let comp () =
  let x = Inner.get () in
  let y = Outer.get () in
  Printf.printf "inner = %d, outer = %d\n" x y

let () =
  Outer.run 1 (fun () ->
    Inner.run 2 comp)

module IntReader = Reader (struct type t = int end)
module StrReader = Reader (struct type t = string end)

let greeting () =
  let name = StrReader.get () in
  let age = IntReader.get () in
  Printf.printf "%s is %d years old\n" name age

let () =
  IntReader.run 30 (fun () ->
    StrReader.run "Alice" greeting)

let () =
  IntReader.run 25 (fun () ->
    StrReader.run "Bob" greeting)

(* Output:
   inner = 2, outer = 1
   Alice is 30 years old
   Bob is 25 years old
*)
