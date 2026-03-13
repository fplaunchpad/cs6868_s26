(** QCheck-STM State Machine Test for Bounded_queue_split_counter *)

open QCheck
open STM

module BQ = Bounded_queue_split_counter

let queue_capacity = 8

module Spec = struct
  type cmd =
    | Try_enq of int
    | Try_deq

  let show_cmd = function
    | Try_enq i -> "Try_enq " ^ string_of_int i
    | Try_deq -> "Try_deq"

  type state = {
    contents : int list;
    capacity : int;
  }

  type sut = int BQ.t

  let arb_cmd _s =
    let int_gen = Gen.small_nat in
    QCheck.make ~print:show_cmd
      (Gen.oneof_weighted [
        (3, Gen.map (fun i -> Try_enq i) int_gen);
        (3, Gen.map (fun _ -> Try_deq) int_gen);
      ])

  let init_state = { contents = []; capacity = queue_capacity }
  let init_sut () = BQ.create queue_capacity
  let cleanup _ = ()

  let next_state c state =
    match c with
    | Try_enq i ->
        if List.length state.contents < state.capacity then
          { state with contents = state.contents @ [i] }
        else
          state
    | Try_deq ->
        (match state.contents with
         | [] -> state
         | _ :: rest -> { state with contents = rest })

  let precond _ _ = true

  let run c d =
    match c with
    | Try_enq i ->
        Res (bool, BQ.try_enq d i)
    | Try_deq ->
        Res (option int, BQ.try_deq d)

  let postcond c state res =
    match (c, res) with
    | Try_enq _, Res ((Bool, _), actual) ->
        actual = (List.length state.contents < state.capacity)
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
      Printf.printf "Running sequential test...\n\n%!";
      let seq_test = Seq.agree_test ~count:5000 ~name:"Split_counter sequential" in
      QCheck_base_runner.run_tests ~verbose:true [seq_test]

  | "concurrent" | "conc" ->
      Printf.printf "Running concurrent test...\n\n%!";
      let arb_cmds_par =
        Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
      in
      let conc_test =
        QCheck.Test.make ~retries:10 ~count:200 ~name:"Split_counter concurrent" arb_cmds_par
        @@ fun triple ->
        QCheck.assume (Dom.all_interleavings_ok triple);
        repeat 12 Dom.agree_prop_par triple
      in
      QCheck_base_runner.run_tests ~verbose:true [conc_test]

  | "all" ->
      Printf.printf "Running all tests...\n\n%!";
      let tests = [
        Seq.agree_test ~count:5000 ~name:"Split_counter sequential";
        QCheck.Test.make ~retries:10 ~count:500 ~name:"Split_counter concurrent"
          (Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd)
          (fun triple -> QCheck.assume (Dom.all_interleavings_ok triple); repeat 12 Dom.agree_prop_par triple);
      ] in
      QCheck_base_runner.run_tests ~verbose:true tests

  | _ ->
      Printf.eprintf "Usage: %s [sequential|concurrent|all]\n" Sys.argv.(0);
      Printf.eprintf "  sequential : Test sequential execution model\n";
      Printf.eprintf "  concurrent : Test concurrent execution\n";
      Printf.eprintf "  all        : Run all tests\n";
      exit 1

let () =
  let test_name =
    if Array.length Sys.argv > 1 then
      Sys.argv.(1)
    else
      "all"
  in
  Printf.printf "QCheck-STM Tests for Bounded_queue_split_counter\n\n";
  ignore (run_test test_name)
