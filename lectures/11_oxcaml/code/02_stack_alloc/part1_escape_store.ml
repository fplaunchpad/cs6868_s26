(* Storing a stack_-allocated value in a top-level (global) ref fails. *)

type point = { x : float; y : float }

let storage : point ref = ref { x = 0.0; y = 0.0 }

let store_local () =
  let p = stack_ { x = 1.0; y = 2.0 } in
  storage := p

(* Error: This value is local because it is stack_-allocated.
          However, the highlighted expression is expected to be global. *)
