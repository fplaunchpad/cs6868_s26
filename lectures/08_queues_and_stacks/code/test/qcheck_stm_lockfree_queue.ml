(** QCheck-STM State Machine Test for LockFreeQueue

    This test uses QCheck-STM to verify the lock-free queue's correctness
    against a sequential specification (a simple list-based unbounded FIFO).

    Tests demonstrate:
    - Sequential operations match the model
    - Concurrent operations (multiple domains) are linearizable
*)

open QCheck
open STM

module LFQ = Lockfree_queue

module Spec = struct
  type cmd =
    | Enq of int
    | Try_deq

  let show_cmd = function
    | Enq i -> "Enq " ^ string_of_int i
    | Try_deq -> "Try_deq"

  (** Model state: unbounded FIFO queue as a list (head = front) *)
  type state = {
    contents : int list;
  }

  type sut = int LFQ.t

  let arb_cmd _s =
    let int_gen = Gen.small_nat in
    QCheck.make ~print:show_cmd
      (Gen.frequency [
        (3, Gen.map (fun i -> Enq i) int_gen);
        (3, Gen.map (fun _ -> Try_deq) int_gen);
      ])

  let init_state = { contents = [] }
  let init_sut () = LFQ.create ()
  let cleanup _ = ()

  let next_state c state =
    match c with
    | Enq i ->
        { contents = state.contents @ [i] }
    | Try_deq ->
        (match state.contents with
         | [] -> state
         | _ :: rest -> { contents = rest })

  let precond _ _ = true

  let run c d =
    match c with
    | Enq i ->
        Res (unit, LFQ.enq d i)
    | Try_deq ->
        Res (option int, LFQ.try_deq d)

  let postcond c state res =
    match (c, res) with
    | Enq _, Res ((Unit, _), ()) ->
        true  (* enq always succeeds on unbounded queue *)
    | Try_deq, Res ((Option Int, _), actual) ->
        (match state.contents with
         | [] -> actual = None
         | x :: _ -> actual = Some x)
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
      let seq_test = Seq.agree_test ~count:5000 ~name:"LockFreeQueue sequential" in
      QCheck_base_runner.run_tests ~verbose:true [seq_test]

  | "concurrent" | "conc" ->
      Printf.printf "Running concurrent test (should pass)...\n\n%!";
      let arb_cmds_par =
        Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
      in
      let conc_test =
        QCheck.Test.make ~retries:10 ~count:200 ~name:"LockFreeQueue concurrent" arb_cmds_par
        @@ fun triple ->
        QCheck.assume (Dom.all_interleavings_ok triple);
        repeat 12 Dom.agree_prop_par triple
      in
      QCheck_base_runner.run_tests ~verbose:true [conc_test]

  | "all" ->
      Printf.printf "Running all tests...\n\n%!";
      let tests = [
        Seq.agree_test ~count:5000 ~name:"LockFreeQueue sequential";
        QCheck.Test.make ~retries:10 ~count:500 ~name:"LockFreeQueue concurrent"
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
  Printf.printf "QCheck-STM Tests for LockFreeQueue\n\n";
  ignore (run_test test_name)
