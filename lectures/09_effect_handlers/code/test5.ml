open Effect
open Effect.Deep

type _ Effect.t += A : unit t
                 | B : unit t

let baz () =
  perform A

let bar () =
  try
    baz ()
  with effect B, k ->
    continue k ()

let foo () =
  try
    bar ()
  with effect A, k ->
    continue k ()

let _ = foo ()