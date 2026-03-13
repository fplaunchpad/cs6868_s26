(** QCheck-STM State Machine Test for LockFreeStack

    This test uses QCheck-STM to verify the lock-free stack's correctness
    against a sequential specification (a simple list-based unbounded LIFO).

    Tests demonstrate:
    - Sequential operations match the model
    - Concurrent operations (multiple domains) are linearizable
*)

open QCheck
open STM

module LFS = Lockfree_stack

module Spec = struct
  type cmd =
    | Push of int
    | Try_pop
    | Pop

  let show_cmd = function
    | Push i -> "Push " ^ string_of_int i
    | Try_pop -> "Try_pop"
    | Pop -> "Pop"

  (** Model state: unbounded LIFO stack as a list (head = top) *)
  type state = {
    contents : int list;
  }

  type sut = int LFS.t

  let arb_cmd _s =
    let int_gen = Gen.small_nat in
    QCheck.make ~print:show_cmd
      (Gen.oneof_weighted [
        (3, Gen.map (fun i -> Push i) int_gen);
        (2, Gen.map (fun _ -> Try_pop) int_gen);
        (2, Gen.map (fun _ -> Pop) int_gen);
      ])

  let init_state = { contents = [] }
  let init_sut () = LFS.create ()
  let cleanup _ = ()

  let next_state c state =
    match c with
    | Push i ->
        { contents = i :: state.contents }
    | Try_pop | Pop ->
        (match state.contents with
         | [] -> state
         | _ :: rest -> { contents = rest })

  let precond _ _ = true

  let run c d =
    match c with
    | Push i ->
        Res (unit, LFS.push d i)
    | Try_pop ->
        Res (option int, LFS.try_pop d)
    | Pop ->
        Res (result int exn, protect LFS.pop d)

  let postcond c state res =
    match (c, res) with
    | Push _, Res ((Unit, _), ()) ->
        true  (* push always succeeds on unbounded stack *)
    | Try_pop, Res ((Option Int, _), actual) ->
        (match state.contents with
         | [] -> actual = None
         | x :: _ -> actual = Some x)
    | Pop, Res ((Result (Int, Exn), _), actual) ->
        (match state.contents with
         | [] -> actual = Error LFS.Empty
         | x :: _ -> actual = Ok x)
    | _, _ -> false
end

let rec repeat n f x =
  if n <= 0 then true
  else f x && repeat (n - 1) f x

let run_test test_name =
  let module Seq = STM_sequential.Make(Spec) in
  let module Dom = STM_domain.Make(Spec) in

  match test_name with
  | "sequential" | "seq" ->
      Printf.printf "Running sequential test (should pass)...\n\n%!";
      let seq_test = Seq.agree_test ~count:5000 ~name:"LockFreeStack sequential" in
      QCheck_base_runner.run_tests ~verbose:true [seq_test]

  | "concurrent" | "conc" ->
      Printf.printf "Running concurrent test (should pass)...\n\n%!";
      let arb_cmds_par =
        Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
      in
      let conc_test =
        QCheck.Test.make ~retries:10 ~count:200 ~name:"LockFreeStack concurrent" arb_cmds_par
        @@ fun triple ->
        QCheck.assume (Dom.all_interleavings_ok triple);
        repeat 12 Dom.agree_prop_par triple
      in
      QCheck_base_runner.run_tests ~verbose:true [conc_test]

  | "all" ->
      Printf.printf "Running all tests...\n\n%!";
      let tests = [
        Seq.agree_test ~count:5000 ~name:"LockFreeStack sequential";
        QCheck.Test.make ~retries:10 ~count:500 ~name:"LockFreeStack concurrent"
          (Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd)
          (fun triple -> QCheck.assume (Dom.all_interleavings_ok triple); repeat 12 Dom.agree_prop_par triple);
      ] in
      QCheck_base_runner.run_tests ~verbose:true tests

  | _ ->
      Printf.eprintf "Usage: %s [sequential|concurrent|all]\n" Sys.argv.(0);
      Printf.eprintf "  sequential : Test sequential execution model\n";
      Printf.eprintf "  concurrent : Test concurrent execution (should pass)\n";
      Printf.eprintf "  all        : Run all tests\n";
      exit 1

let () =
  let test_name =
    if Array.length Sys.argv > 1 then
      Sys.argv.(1)
    else
      "all"
  in
  Printf.printf "QCheck-STM Tests for LockFreeStack\n\n";
  ignore (run_test test_name)
