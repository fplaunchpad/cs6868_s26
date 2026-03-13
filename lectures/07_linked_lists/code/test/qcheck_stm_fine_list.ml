(** QCheck-STM State Machine Test for FineList

    This test uses QCheck-STM to verify the fine-grained list's correctness.
    The list uses hand-over-hand locking, so it should be safe for all
    concurrent access patterns.

    Tests demonstrate:
    - Sequential operations work correctly
    - Concurrent operations (multiple domains) are safe
*)

open QCheck
open STM

module FL = Fine_list

(** Utility function for repeating tests *)
let rec repeat n f x =
  if n <= 0 then true
  else f x && repeat (n - 1) f x

module Spec = struct
  type cmd =
    | Add of int
    | Remove of int
    | Contains of int

  let show_cmd c =
    match c with
    | Add i -> "Add " ^ string_of_int i
    | Remove i -> "Remove " ^ string_of_int i
    | Contains i -> "Contains " ^ string_of_int i

  (** State: set of integers currently in the list *)
  type state = int list
  type sut = int FL.t

  (** Generate arbitrary commands *)
  let arb_cmd _s =
    let int_gen = Gen.small_nat in
    QCheck.make ~print:show_cmd
      (Gen.oneof_weighted [
        (3, Gen.map (fun i -> Add i) int_gen);
        (2, Gen.map (fun i -> Remove i) int_gen);
        (2, Gen.map (fun i -> Contains i) int_gen);
      ])

  let init_state = []
  let init_sut () = FL.create ()
  let cleanup _ = ()

  (** Update the model state based on the command *)
  let next_state c state =
    match c with
    | Add i ->
        if List.mem i state then
          state  (* Already present, no change *)
        else
          i :: state  (* Add to set *)
    | Remove i ->
        List.filter ((<>) i) state  (* Remove from set *)
    | Contains _ ->
        state  (* Queries don't change state *)

  let precond _ _ = true

  (** Execute the command on the real implementation *)
  let run c d =
    match c with
    | Add i ->
        Res (bool, FL.add d i)
    | Remove i ->
        Res (bool, FL.remove d i)
    | Contains i ->
        Res (bool, FL.contains d i)

  (** Check if the actual result matches expectations from the model *)
  let postcond c state res =
    match (c, res) with
    | Add i, Res ((Bool, _), actual) ->
        (* add returns true if element was newly added *)
        actual = not (List.mem i state)
    | Remove i, Res ((Bool, _), actual) ->
        (* remove returns true if element was present *)
        actual = List.mem i state
    | Contains i, Res ((Bool, _), actual) ->
        (* contains returns true if element is present *)
        actual = List.mem i state
    | _, _ -> false
end

(** Run tests based on command-line argument *)
let run_test test_name =
  let module Seq = STM_sequential.Make(Spec) in
  let module Dom = STM_domain.Make(Spec) in

  match test_name with
  | "sequential" | "seq" ->
      Printf.printf "Running sequential test (should pass)...\n\n%!";
      let seq_test = Seq.agree_test ~count:5000 ~name:"FineList sequential" in
      QCheck_base_runner.run_tests ~verbose:true [seq_test]

  | "concurrent" | "conc" ->
      Printf.printf "Running concurrent test (should pass)...\n\n%!";
      let arb_cmds_par =
        Dom.arb_triple 12 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
      in
      let conc_test =
        QCheck.Test.make ~retries:10 ~count:200 ~name:"FineList concurrent" arb_cmds_par
        @@ fun triple ->
        QCheck.assume (Dom.all_interleavings_ok triple);
        repeat 12 Dom.agree_prop_par triple
      in
      QCheck_base_runner.run_tests ~verbose:true [conc_test]

  | "all" ->
      Printf.printf "Running all tests...\n\n%!";
      let tests =[
        Seq.agree_test ~count:5000 ~name:"FineList sequential";
        QCheck.Test.make ~retries:10 ~count:200 ~name:"FineList concurrent"
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
  Printf.printf "QCheck-STM Tests for FineList\n\n";
  ignore (run_test test_name)
