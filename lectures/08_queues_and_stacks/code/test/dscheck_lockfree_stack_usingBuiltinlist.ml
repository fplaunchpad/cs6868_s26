(** DSCheck test for a lock-free stack (builtin-list Treiber stack).*)

module Atomic = Dscheck.TracedAtomic
module Stack = Lockfree_stack_builtin_list


(* ------------------------------------------------------------------ *)
(* Test 1 : two concurrent pushes                                      *)
(* ------------------------------------------------------------------ *)
(* Two domains each push one distinct value onto an empty stack.
   After both finish, the stack must contain exactly those two values
   (in either order — LIFO order depends on which CAS won). *)

let two_pushes () =
(* Try to run all possible interleaving *)
Atomic.trace (fun () ->
    let s = Stack.create () in
    Atomic.spawn (fun () -> Stack.push s 1);
    Atomic.spawn (fun () -> Stack.push s 2);
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let r1 = Stack.try_pop s in
        let r2 = Stack.try_pop s in
        let r3 = Stack.try_pop s in
        match r1, r2, r3 with
        | Some a, Some b, None -> List.sort compare [ a; b ] = [ 1; 2 ]
        | _ -> false)))

(* ------------------------------------------------------------------ *)
(* Test 2 : one push and one pop, racing on an empty stack            *)
(* ------------------------------------------------------------------ *)
(* Two valid linearizations:
     (a) pop first  - returns None,  then push - stack = [42]
     (b) push first - stack = [42],  then pop  - returns Some 42, stack = []
   The check accepts both outcomes and rejects everything else. *)

let push_and_pop () =
  Atomic.trace (fun () ->
    let s      = Stack.create () in
    let popped = Atomic.make None in
    Atomic.spawn (fun () -> Stack.push s 42);
    Atomic.spawn (fun () -> Atomic.set popped (Stack.try_pop s));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        match Atomic.get popped with
        | None   -> Stack.try_pop s = Some 42          (* pop ran before push *)
        | Some 42 -> Stack.try_pop s = None             (* pop ran after push *)
        | _ -> false)))

(* ------------------------------------------------------------------ *)
(* Test 3 : two concurrent pops on a two-element stack                *)
(* ------------------------------------------------------------------ *)
(* Pre-load [2; 1] (2 on top).  Two domains each call try_pop.
   Because the stack has exactly 2 elements and both pops succeed,
   each domain must get a distinct value and the stack ends empty. *)

let two_pops () =
  Atomic.trace (fun () ->
    let s  = Stack.create () in
    Stack.push s 1;
    Stack.push s 2;           (* stack is now [2; 1] *)
    let r1 = Atomic.make None in
    let r2 = Atomic.make None in
    Atomic.spawn (fun () -> Atomic.set r1 (Stack.try_pop s));
    Atomic.spawn (fun () -> Atomic.set r2 (Stack.try_pop s));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        match Atomic.get r1, Atomic.get r2 with
        | Some a, Some b ->
            List.sort compare [a; b] = [1; 2]
            && Stack.try_pop s = None
        | _ -> false)))  (* one pop returning None would be a bug *)


(* Conservation Property: *)
(* Two values are pushed and two concurrent pops are executed.this checks that the stack never loses or duplicates elements. *)
let conservation () =
Atomic.trace (fun () ->
let s = Stack.create () in

let r1 = Atomic.make None in
let r2 = Atomic.make None in

Atomic.spawn (fun () -> Stack.push s 1);
Atomic.spawn (fun () -> Stack.push s 2);

Atomic.spawn (fun () ->
  Atomic.set r1 (Stack.try_pop s));

Atomic.spawn (fun () ->
  Atomic.set r2 (Stack.try_pop s));

Atomic.final (fun () ->
  Atomic.check (fun () ->
    let elems = ref [] in

    (match Atomic.get r1 with
     | Some x -> elems := x :: !elems
     | None -> ());

    (match Atomic.get r2 with
     | Some x -> elems := x :: !elems
     | None -> ());

    (match Stack.try_pop s with
     | Some x -> elems := x :: !elems
     | None -> ());

    (match Stack.try_pop s with
     | Some x -> elems := x :: !elems
     | None -> ());

    List.sort compare !elems = [1; 2])))


let () =
    (* Directy calling/checking each property.   *)
  two_pushes ();
  print_endline "two-pushes test passed!";

  push_and_pop ();
  print_endline "push-pop test passed!";

  two_pops ();
  print_endline "two-pops test passed!";

  conservation ();
  print_endline "conservation test passed!";

  print_endline "All dscheck_lockfree_stack_usingBuiltinlist tests passed!"

