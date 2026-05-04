(* Storing a stack_-allocated value in a global ref fails. *)

type point = { x : float; y : float }

let store_local () =
  let p = stack_ { x = 1.0; y = 2.0 } in
  let r = ref p in
  !r

(* Error: This value is local because it is stack_-allocated.
          However, the highlighted expression is expected to be global. *)
