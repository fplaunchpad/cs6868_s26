(** QCheck-STM State Machine Test for Atomic Snapshot

    This test verifies the atomic snapshot against a sequential model using
    QCheck's State Machine Testing framework.

    == Your Task ==

    Complete the TODO sections below. The structure is provided, but you need
    to implement the key testing functions that define correctness.

    Study the examples from Lecture 3:
    - qcheck_stm_lockfree.ml

    == What is STM Testing? ==

    State Machine Testing compares your concurrent implementation against
    a simple sequential model:

    1. We define a model state (simple array representing registers)
    2. Each command (Update/Scan) has:
       - next_state: how it should update the model
       - run: how to execute it on the real implementation
       - postcond: verify real result matches model prediction
    3. QCheck generates random command sequences and checks if real
       execution matches model
*)

open QCheck
open STM

(** Sequential model state - just an array *)
type model_state = int array

(** Commands that can be performed on the snapshot *)
type snapshot_cmd =
  | Update of int * int  (* Update(idx, value) *)
  | Scan                  (* Scan() *)

(** Initialize both model state and real snapshot *)
let n = 4 (* Number of registers *)
let init_state = Array.make n 0  (* Model state: array of 0s *)
let init_sut () = Snapshot.create n 0
let cleanup _ = ()

(** Show command for debugging *)
let show_cmd = function
  | Update (idx, value) -> Printf.sprintf "Update(%d, %d)" idx value
  | Scan -> "Scan()"

(** Generate random commands *)
let arb_cmd _state =
  QCheck.make ~print:show_cmd
    (Gen.frequency [
      (3, Gen.map2 (fun idx value -> Update (idx, value))
            (Gen.int_range 0 3)  (* index 0-3 *)
            (Gen.int_range 0 99)); (* value 0-99 *)
      (2, Gen.return Scan);
    ])

(* ============================================================================
   TODO: Implement next_state

   Update the model state according to the command.
   This defines the "correct" sequential behavior.

   Hints:
   - For Update(idx, value): update the model array at index idx
   - For Scan: the model state doesn't change (Scan is read-only)
   ============================================================================ *)
let next_state cmd state =
  failwith "TODO: Implement next_state"

(** Precondition - all commands are always valid for snapshot *)
let precond _cmd _state = true

(** Run command on the real implementation *)
let run cmd snapshot =
  match cmd with
  | Update (idx, value) ->
      Snapshot.update snapshot idx value;
      Res (unit, ())
  | Scan ->
      let arr = Snapshot.scan snapshot in
      Res (array int, arr)

(* ============================================================================
   TODO: Implement postcond

   Check if the real result matches what the model predicts.

   Hints:
   - For Update: returns unit, should always succeed (return true)
   - For Scan: returns array, should match the model state
     BUT: due to concurrency, it might match an *earlier* state!

   For this assignment, we'll accept any valid state (this is a simplified
   postcondition - a full STM test for snapshots is complex due to the
   lock-free nature).

   Return true if result is acceptable, false otherwise.
   ============================================================================ *)
let postcond cmd state result =
  failwith "TODO: Implement postcond"

(** QCheck-STM specification *)
module Spec = struct
  type sut = int Snapshot.t
  type state = model_state
  type cmd = snapshot_cmd

  let arb_cmd = arb_cmd
  let init_state = init_state
  let next_state = next_state
  let precond = precond
  let run = run
  let init_sut = init_sut
  let cleanup = cleanup
  let postcond = postcond
  let show_cmd = show_cmd
end

(** Sequential and concurrent test modules *)
module Seq = STM_sequential.Make(Spec)
module Dom = STM_domain.Make(Spec)

(* ============================================================================
   TODO: Understand what these tests do

   - Sequential test: runs commands one by one, checking postconditions
   - Concurrent test: runs commands in parallel domains, checking linearizability

   Try running:
     dune exec ./qcheck_stm_snapshot.exe -- sequential
     dune exec ./qcheck_stm_snapshot.exe -- concurrent
   ============================================================================ *)

let run_sequential_test () =
  Printf.printf "Running sequential STM test...\n\n%!";
  let seq_test = Seq.agree_test ~count:1000 ~name:"Snapshot sequential" in
  QCheck_base_runner.run_tests ~verbose:true [seq_test]

let run_concurrent_test () =
  Printf.printf "Running concurrent STM test...\n\n%!";
  let arb_cmds_par =
    Dom.arb_triple 15 10 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
  in
  let conc_test =
    QCheck.Test.make ~retries:10 ~count:200 ~name:"Snapshot concurrent" arb_cmds_par
    @@ fun triple ->
    Dom.agree_prop_par triple
  in
  QCheck_base_runner.run_tests ~verbose:true [conc_test]

(** Main entry point - choose test based on command line argument *)
let () =
  let test_name = if Array.length Sys.argv > 1 then Sys.argv.(1) else "sequential" in
  match test_name with
  | "sequential" | "seq" -> ignore (run_sequential_test ())
  | "concurrent" | "conc" -> ignore (run_concurrent_test ())
  | _ ->
      Printf.eprintf "Usage: %s [sequential|concurrent]\n" Sys.argv.(0);
      exit 1
