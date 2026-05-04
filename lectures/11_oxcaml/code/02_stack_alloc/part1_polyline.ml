(* Lecture 11, Part 1: Safe Stack Allocation
   Polyline running example. *)

(* Locality: local vs global. *)

let use_locally (x @ local) = x + 1

(* Stack allocation with stack_. *)

type point = { x : float; y : float }

let distance (a @ local) (b @ local) =
  let dx = a.x -. b.x in
  let dy = a.y -. b.y in
  Float.sqrt (dx *. dx +. dy *. dy)

let test_distance () =
  let a = stack_ { x = 0.0; y = 0.0 } in
  let b = stack_ { x = 3.0; y = 4.0 } in
  let d = distance a b in
  d

(* Returning local values with exclave_. *)

let midpoint (a @ local) (b @ local) : point @ local =
  exclave_ { x = (a.x +. b.x) /. 2.0; y = (a.y +. b.y) /. 2.0 }

let translate (p @ local) (dx : float) (dy : float) : point @ local =
  exclave_ { x = p.x +. dx; y = p.y +. dy }

(* Mode crossing: float results escape freely. *)

let triangle_perimeter (a @ local) (b @ local) (c @ local) : float =
  distance a b +. distance b c +. distance c a

let test_perimeter () =
  let a = stack_ { x = 0.0; y = 0.0 } in
  let b = stack_ { x = 3.0; y = 0.0 } in
  let c = stack_ { x = 3.0; y = 4.0 } in
  let p = triangle_perimeter a b c in
  p

(* Local lists: traversal (no allocation) and map-style construction. *)

let rec path_length (poly : point list @ local) : float =
  match poly with
  | a :: (b :: _ as rest) -> distance a b +. path_length rest
  | _ -> 0.0

let rec translate_polyline (poly : point list @ local) dx dy
    : point list @ local =
  match poly with
  | [] -> exclave_ []
  | p :: rest ->
      exclave_ (translate p dx dy :: translate_polyline rest dx dy)
