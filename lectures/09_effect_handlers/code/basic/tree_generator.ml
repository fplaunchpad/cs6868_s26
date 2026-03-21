open Effect
open Effect.Deep

(* ──────────────────────────────────────────────────────────────────────
 * Control Inversion: Tree Iterator → Tree Generator
 *
 * An *internal iterator* (push-based) traverses the tree and pushes each
 * element to a callback — the producer is in control.
 *
 * A *generator* (pull-based) lets the consumer ask for the next element
 * on demand — the consumer is in control.
 *
 * With effect handlers we can mechanically convert one into the other:
 * the iterator performs a Yield effect at each element, and the handler
 * suspends the traversal, returning the value and a thunk to resume.
 * ────────────────────────────────────────────────────────────────────── *)

(* ---------- Tree type ---------- *)

type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

(*       1
 *      / \
 *     2   3
 *    / \   \
 *   4   5   6
 *)
let example_tree =
  Node (
    Node (Node (Leaf, 4, Leaf), 2, Node (Leaf, 5, Leaf)),
    1,
    Node (Leaf, 3, Node (Leaf, 6, Leaf)))

(* ---------- Internal iterator (push-based) ---------- *)

let rec iter t f = match t with
  | Leaf -> ()
  | Node (l, x, r) ->
    iter l f;
    f x;
    iter r f

(* ---------- Generator via effect handlers ---------- *)

(* [to_gen t] converts the internal iterator into a pull-based generator.
 * Returns a [next] function: each call returns [Some v] for the next element,
 * or [None] when the traversal is done.
 *
 * The trick: a local effect [Next] is performed at each element.  The handler
 * captures the continuation, stashes it in [step], and returns the value.
 * On the next call, we resume the continuation — which runs until the next
 * [Next] (updating [step] again) or finishes (returning [None]). *)
let to_gen (type a) (iter : (a -> unit) -> unit) =
  let module M = struct type _ Effect.t += Next : a -> unit Effect.t end in
  let open M in
  let rec step = ref (fun () ->
    try
      iter (fun x -> perform (Next x));
      None
    with effect (Next v), k ->
      step := (fun () -> continue k ());
      Some v)
  in
  fun () -> !step ()

(* ---------- Consumer: pull values one at a time ---------- *)

let print_all next =
  let rec go () =
    match next () with
    | None -> ()
    | Some v ->
      Printf.printf "  got %d\n" v;
      go ()
  in
  go ()

(* ---------- Same-fringe test: two trees have the same leaves ---------- *)

let rec same_fringe next1 next2 =
  match next1 (), next2 () with
  | None, None -> true
  | Some v1, Some v2 -> v1 = v2 && same_fringe next1 next2
  | _ -> false

(* ====================================================================== *)

(* Test 1: Push-based internal iteration *)
let () =
  Printf.printf "=== Internal iterator (push-based) ===\n";
  iter example_tree (fun x -> Printf.printf "  visited %d\n" x)
(* Output:
  === Internal iterator (push-based) ===
    visited 4
    visited 2
    visited 5
    visited 1
    visited 3
    visited 6
*)

(* Test 2: Pull-based generator via control inversion *)
let () =
  Printf.printf "\n=== Generator (pull-based) ===\n";
  let next = to_gen (iter example_tree) in
  print_all next
(* Output:
  === Generator (pull-based) ===
    got 4
    got 2
    got 5
    got 1
    got 3
    got 6
*)

(* Test 3: Same-fringe problem
 *
 * Two differently shaped trees with the same in-order traversal:
 *
 *    tree_a:       tree_b:
 *       2            1
 *      / \          / \
 *     1   3        2   3
 *
 * Both yield 1, 2, 3 in-order.
 *)
let () =
  Printf.printf "\n=== Same-fringe test ===\n";
  let tree_a = Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)) in
  let tree_b = Node (Leaf, 1, Node (Leaf, 2, Node (Leaf, 3, Leaf))) in
  let tree_c = Node (Leaf, 1, Node (Leaf, 4, Node (Leaf, 3, Leaf))) in
  Printf.printf "  tree_a = tree_b? %b\n" (same_fringe (to_gen (iter tree_a)) (to_gen (iter tree_b)));
  Printf.printf "  tree_a = tree_c? %b\n" (same_fringe (to_gen (iter tree_a)) (to_gen (iter tree_c)))
(* Output:
  === Same-fringe test ===
    tree_a = tree_b? true
    tree_a = tree_c? false
*)
