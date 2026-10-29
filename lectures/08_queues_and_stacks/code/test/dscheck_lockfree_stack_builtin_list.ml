(** DSCheck tests for the built-in-list Treiber stack
    ([Lockfree_stack_builtin_list]).

    DSCheck can only explore interleavings of atomic operations it can
    see, so the stack under test is [Lockfree_stack_builtin_list.Make]
    instantiated with [Dscheck.TracedAtomic]: every read and CAS on the
    list reference inside [push] and [try_pop] becomes a scheduling point.
    Backoff is disabled because model checking needs deterministic runs.  [Atomic.trace] runs the test
    body once for every (non-equivalent) interleaving of the spawned
    threads, and [Atomic.check] fails if the property is violated in any
    of them, printing the offending interleaving. *)

module Atomic = Dscheck.TracedAtomic

module Tests (Stack : Lockfree_stack_builtin_list.S) = struct
  (* Pop everything left on the stack, top first. *)
  let drain s =
    let rec loop acc =
      match Stack.try_pop s with
      | Some x -> loop (x :: acc)
      | None -> List.rev acc
    in
    loop []

  (* Test 1: two concurrent pushes.  Neither value is lost. *)
  let two_pushes () =
    Atomic.trace (fun () ->
      let s = Stack.create () in
      Atomic.spawn (fun () -> Stack.push s 1);
      Atomic.spawn (fun () -> Stack.push s 2);
      Atomic.final (fun () ->
        Atomic.check (fun () ->
          List.sort compare (drain s) = [ 1; 2 ])))

  (* Test 2: a push racing with a pop on an empty stack.
     Two valid linearizations:
       pop first  -> pop returns None,    42 is left on the stack
       push first -> pop returns Some 42, the stack ends empty *)
  let push_and_pop () =
    Atomic.trace (fun () ->
      let s = Stack.create () in
      let popped = Atomic.make None in
      Atomic.spawn (fun () -> Stack.push s 42);
      Atomic.spawn (fun () -> Atomic.set popped (Stack.try_pop s));
      Atomic.final (fun () ->
        Atomic.check (fun () ->
          match Atomic.get popped, drain s with
          | None, [ 42 ] | Some 42, [] -> true
          | _ -> false)))

  (* Test 3: two concurrent pops on a two-element stack.
     Each pop gets a distinct element and the stack ends empty. *)
  let two_pops () =
    Atomic.trace (fun () ->
      let s = Stack.create () in
      Stack.push s 1;
      Stack.push s 2;
      let r1 = Atomic.make None in
      let r2 = Atomic.make None in
      Atomic.spawn (fun () -> Atomic.set r1 (Stack.try_pop s));
      Atomic.spawn (fun () -> Atomic.set r2 (Stack.try_pop s));
      Atomic.final (fun () ->
        Atomic.check (fun () ->
          match Atomic.get r1, Atomic.get r2 with
          | Some a, Some b -> List.sort compare [ a; b ] = [ 1; 2 ] && drain s = []
          | _ -> false)))

  (* Test 4: LIFO order under a push/pop race.
     Starting from [2; 1] (2 on top), one thread pushes 3 while another
     pops.  The pop takes whichever element is on top at its CAS:
       pop first  -> pops 2, stack ends [3; 1]
       push first -> pops 3, stack ends [2; 1]
     Element 1, at the bottom, can never be popped. *)
  let lifo () =
    Atomic.trace (fun () ->
      let s = Stack.create () in
      Stack.push s 1;
      Stack.push s 2;
      let popped = Atomic.make None in
      Atomic.spawn (fun () -> Stack.push s 3);
      Atomic.spawn (fun () -> Atomic.set popped (Stack.try_pop s));
      Atomic.final (fun () ->
        Atomic.check (fun () ->
          match Atomic.get popped, drain s with
          | Some 2, [ 3; 1 ] | Some 3, [ 2; 1 ] -> true
          | _ -> false)))

  (* Test 5: conservation — elements are neither lost nor duplicated.
     Two pushes race with two pops; whatever the pops returned plus
     whatever is left on the stack is exactly {1, 2}. *)
  let conservation () =
    Atomic.trace (fun () ->
      let s = Stack.create () in
      let r1 = Atomic.make None in
      let r2 = Atomic.make None in
      Atomic.spawn (fun () -> Stack.push s 1);
      Atomic.spawn (fun () -> Stack.push s 2);
      Atomic.spawn (fun () -> Atomic.set r1 (Stack.try_pop s));
      Atomic.spawn (fun () -> Atomic.set r2 (Stack.try_pop s));
      Atomic.final (fun () ->
        Atomic.check (fun () ->
          let popped = List.filter_map Fun.id [ Atomic.get r1; Atomic.get r2 ] in
          List.sort compare (popped @ drain s) = [ 1; 2 ])))
end

module T =
  Tests (Lockfree_stack_builtin_list.Make (Atomic) (Backoff.No_backoff))

(* Negative test: the same stack built on a CAS that is NOT atomic (a read
   followed by a separate write).  Two pushes can then both read the same
   list and one of them is lost.  DSCheck must find that interleaving; if
   it does not, the tests above are not exploring the stack's internals. *)
module Racy_cas = struct
  include Atomic

  let compare_and_set r seen v =
    if get r == seen then (set r v; true) else false
end

module Racy =
  Tests (Lockfree_stack_builtin_list.Make (Racy_cas) (Backoff.No_backoff))

let expect_violation name test =
  match test () with
  | () -> failwith (name ^ ": DSCheck found no violation in a buggy stack")
  | exception Assert_failure _ ->
    print_endline (name ^ ": violation found, as expected")

let () =
  T.two_pushes ();
  print_endline "Two pushes test passed!";
  T.push_and_pop ();
  print_endline "Push/pop race test passed!";
  T.two_pops ();
  print_endline "Two pops test passed!";
  T.lifo ();
  print_endline "LIFO test passed!";
  T.conservation ();
  print_endline "Conservation test passed!";
  (* Run last: DSCheck's global state is not reset after a failed check. *)
  expect_violation "Racy CAS, two pushes" Racy.two_pushes;
  print_endline "All dscheck_lockfree_stack_builtin_list tests passed!"
