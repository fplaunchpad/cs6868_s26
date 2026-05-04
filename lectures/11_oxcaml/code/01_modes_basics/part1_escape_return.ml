(* Returning a stack_-allocated value fails. *)

type point = { x : float; y : float }

let escape_demo () =
  let p = stack_ { x = 1.0; y = 2.0 } in
  p

(* Error: This value is local because it is stack_-allocated.
          However, the highlighted expression is expected to be
          local to the parent region or global because it is a
          function return value.
          Hint: Use exclave_ to return a local value. *)
