(** QCheck-STM State Machine Test for Lock-Free Queue

    This test uses QCheck-STM to verify the lock-free queue's correctness.
    The queue is ONLY safe for SPSC (Single Producer, Single Consumer).

    Tests demonstrate:
    - Sequential operations work correctly
    - SPSC (one producer, one consumer) is safe
    - MPMC, MPSC, SPMC all violate safety and show failures
*)

open QCheck
open STM

module LF = Concurrent_queues.Lockfree_queue

(** Utility function for repeating tests *)
let rec repeat n f x =
  if n <= 0 then true
  else f x && repeat (n - 1) f x

module Spec = struct
  type cmd =
    | Enq of int
    | Deq
    | Is_empty
    | Is_full
    | Size

  let show_cmd c =
    match c with
    | Enq i -> "Enq " ^ string_of_int i
    | Deq -> "Deq"
    | Is_empty -> "Is_empty"
    | Is_full -> "Is_full"
    | Size -> "Size"

  (** State: (capacity, current_size, queue_contents_as_list) *)
  type state = int * int * int list
  type sut = int LF.t

  (** Producer commands with occasional size queries *)
  let producer_cmd _s =
    let int_gen = Gen.nat in
    QCheck.make ~print:show_cmd
      (Gen.oneof_weighted [
        (8, Gen.map (fun i -> Enq i) int_gen);
        (1, Gen.return Size);
      ])

  (** Consumer commands *)
  let consumer_cmd _s =
    QCheck.make ~print:show_cmd
      (Gen.oneof [
        Gen.return Deq;
        Gen.return Is_empty;
        Gen.return Is_full;
        Gen.return Size;
      ])

  (** All commands for sequential testing *)
  let arb_cmd _s =
    let int_gen = Gen.nat in
    QCheck.make ~print:show_cmd
      (Gen.oneof [
        Gen.map (fun i -> Enq i) int_gen;
        Gen.return Deq;
        Gen.return Is_empty;
        Gen.return Is_full;
        Gen.return Size;
      ])

  let capacity = 10
  let init_state = (capacity, 0, [])
  let init_sut () = LF.create capacity
  let cleanup _ = ()

  (** Update the model state based on the command *)
  let next_state c (cap, size, contents) =
    match c with
    | Enq i ->
        if size >= cap then
          (cap, size, contents)  (* Queue full, no change *)
        else
          (cap, size + 1, contents @ [i])  (* Append to tail *)
    | Deq ->
        begin match contents with
        | [] -> (cap, 0, [])  (* Empty, no change *)
        | _ :: rest -> (cap, size - 1, rest)  (* Remove from head *)
        end
    | Is_empty | Is_full | Size ->
        (cap, size, contents)  (* Queries don't change state *)

  let precond _ _ = true

  (** Execute the command on the real implementation *)
  let run c d =
    match c with
    | Enq i ->
        Res (result unit exn,
          try Ok (LF.enq d i)
          with LF.Full -> Error LF.Full)
    | Deq ->
        Res (result int exn,
          try Ok (LF.deq d)
          with LF.Empty -> Error LF.Empty)
    | Is_empty ->
        Res (bool, LF.is_empty d)
    | Is_full ->
        Res (bool, LF.is_full d)
    | Size ->
        Res (int, LF.size d)

  (** Check if the actual result matches expectations from the model *)
  let postcond c ((cap, size, contents) : state) res =
    match (c, res) with
    | Enq _, Res ((Result (Unit, Exn), _), actual_res) ->
        (* Enqueue should succeed if not full, fail if full *)
        begin match actual_res with
        | Ok () -> size < cap
        | Error e -> size >= cap && e = LF.Full
        end
    | Deq, Res ((Result (Int, Exn), _), actual_res) ->
        (* Dequeue should return head element if not empty, fail if empty *)
        begin match (contents, actual_res) with
        | [], Error e -> e = LF.Empty
        | x :: _, Ok y -> x = y
        | _ -> false
        end
    | Is_empty, Res ((Bool, _), actual_res) ->
        actual_res = (size = 0)
    | Is_full, Res ((Bool, _), actual_res) ->
        actual_res = (size >= cap)
    | Size, Res ((Int, _), actual_res) ->
        actual_res = size
    | _, _ -> false
end

(** Run tests based on command-line argument *)
let run_test test_name =
  let module Seq = STM_sequential.Make(Spec) in
  let module Dom = STM_domain.Make(Spec) in

  match test_name with
  | "sequential" | "seq" ->
      Printf.printf "Running sequential test (should pass)...\n\n%!";
      let seq_test = Seq.agree_test ~count:1000 ~name:"Lockfree_queue sequential" in
      QCheck_base_runner.run_tests ~verbose:true [seq_test]

  | "spsc" ->
      Printf.printf "Running SPSC test - Single Producer, Single Consumer (should pass)...\n\n%!";
      let arb_cmds_par_swsr =
        Dom.arb_triple 20 12
          Spec.producer_cmd   (* Sequential prefix *)
          Spec.producer_cmd   (* Producer domain *)
          Spec.consumer_cmd   (* Consumer domain *)
      in
      let swsr_test =
        let rep_count = 20 in
        Test.make ~retries:10 ~count:100 ~name:"Lockfree_queue SPSC" arb_cmds_par_swsr
        @@ fun triple ->
        assume (Dom.all_interleavings_ok triple);
        repeat rep_count Dom.agree_prop_par_asym triple
      in
      QCheck_base_runner.run_tests ~verbose:true [swsr_test]

  | "mpmc" ->
      Printf.printf "Running MPMC test - Multiple Producers, Multiple Consumers (should fail)...\n";
      Printf.printf "This test WILL show a failure/error - that's expected!\n\n%!";
      let arb_cmds_par_mpmc =
        Dom.arb_triple 10 8 Spec.arb_cmd Spec.arb_cmd Spec.arb_cmd
      in
      let mpmc_test =
        Test.make ~count:100 ~name:"Lockfree_queue MPMC" arb_cmds_par_mpmc
        @@ fun triple ->
        assume (Dom.all_interleavings_ok triple);
        repeat 10 Dom.agree_prop_par_asym triple
      in
      QCheck_base_runner.run_tests ~verbose:true [mpmc_test]

  | "mpsc" ->
      Printf.printf "Running MPSC test - Multiple Producers, Single Consumer (should fail)...\n";
      Printf.printf "This test WILL show a failure/error - that's expected!\n\n%!";
      let arb_cmds_par_mpsc =
        Dom.arb_triple 10 8 Spec.producer_cmd Spec.producer_cmd Spec.producer_cmd
      in
      let mpsc_test =
        Test.make ~count:100 ~name:"Lockfree_queue MPSC" arb_cmds_par_mpsc
        @@ fun triple ->
        assume (Dom.all_interleavings_ok triple);
        repeat 10 Dom.agree_prop_par_asym triple
      in
      QCheck_base_runner.run_tests ~verbose:true [mpsc_test]

  | "spmc" ->
      Printf.printf "Running SPMC test - Single Producer, Multiple Consumers (should fail)...\n";
      Printf.printf "This test WILL show a failure/error - that's expected!\n\n%!";
      let arb_cmds_par_spmc =
        Dom.arb_triple 10 8 Spec.producer_cmd Spec.consumer_cmd Spec.consumer_cmd
      in
      let spmc_test =
        Test.make ~count:100 ~name:"Lockfree_queue SPMC" arb_cmds_par_spmc
        @@ fun triple ->
        assume (Dom.all_interleavings_ok triple);
        repeat 10 Dom.agree_prop_par_asym triple
      in
      QCheck_base_runner.run_tests ~verbose:true [spmc_test]

  | "all" ->
      Printf.printf "Running all tests...\n\n%!";
      let tests = [
        Seq.agree_test ~count:1000 ~name:"Lockfree_queue sequential";
        Test.make ~retries:10 ~count:100 ~name:"Lockfree_queue SPSC"
          (Dom.arb_triple 20 12 Spec.producer_cmd Spec.producer_cmd Spec.consumer_cmd)
          (fun triple -> assume (Dom.all_interleavings_ok triple); repeat 20 Dom.agree_prop_par_asym triple);
        Dom.neg_agree_test_par ~count:100 ~name:"Lockfree_queue MPMC";
        Test.make ~count:100 ~name:"Lockfree_queue MPSC"
          (Dom.arb_triple 10 8 Spec.producer_cmd Spec.producer_cmd Spec.producer_cmd)
          (fun triple -> assume (Dom.all_interleavings_ok triple); repeat 10 Dom.agree_prop_par_asym triple);
        Test.make ~count:100 ~name:"Lockfree_queue SPMC"
          (Dom.arb_triple 10 8 Spec.producer_cmd Spec.consumer_cmd Spec.consumer_cmd)
          (fun triple -> assume (Dom.all_interleavings_ok triple); repeat 10 Dom.agree_prop_par_asym triple);
      ] in
      QCheck_base_runner.run_tests ~verbose:true tests

  | _ ->
      Printf.eprintf "Error: Unknown test '%s'\n\n" test_name;
      exit 1

let print_help () =
  Printf.printf "QCheck-STM Tests for Lock-Free Queue\n\n";
  Printf.printf "Usage: %s <test>\n\n" Sys.argv.(0);
  Printf.printf "Available tests:\n";
  Printf.printf "  sequential, seq   - Sequential operations only (should pass)\n";
  Printf.printf "  spsc              - Single Producer, Single Consumer (should pass)\n";
  Printf.printf "  mpmc              - Multiple Producers, Multiple Consumers (should fail)\n";
  Printf.printf "  mpsc              - Multiple Producers, Single Consumer (should fail)\n";
  Printf.printf "  spmc              - Single Producer, Multiple Consumers (should fail)\n";
  Printf.printf "  all               - Run all tests\n\n";
  Printf.printf "The lockfree queue is ONLY safe for SPSC/SWSR usage!\n";
  exit 0

let () =
  if Array.length Sys.argv < 2 then
    print_help ()
  else
    let exit_code = run_test Sys.argv.(1) in
    exit exit_code
