(** Manual concurrent tests for Batch Bounded Blocking Queue *)

let printf = Printf.printf

let assert_array_eq a b msg =
  if a <> b then begin
    printf "FAIL: %s\n  expected: [|%s|]\n  got:      [|%s|]\n" msg
      (Array.to_list a |> List.map string_of_int |> String.concat "; ")
      (Array.to_list b |> List.map string_of_int |> String.concat "; ");
    exit 1
  end

(** Test create, enq, deq, size, capacity in a single thread. *)
let test_sequential_basic () = failwith "TODO: implement"

(** Test that invalid arguments raise [Invalid_argument]. *)
let test_error_handling () = failwith "TODO: implement"

(** Test that deq blocks until items arrive (and/or enq blocks until space frees). *)
let test_blocking_enq_deq () = failwith "TODO: implement"

(** Test that a single producer/consumer pair sees items in FIFO order. *)
let test_fifo_single_producer_consumer () = failwith "TODO: implement"

(** Test dequeuer head-of-line blocking: deq(5) arrives before deq(2);
    even when 6 items are enqueued, deq(5) must be served first. *)
let test_dequeuer_head_of_line_blocking () = failwith "TODO: implement"

(** Test enqueuer head-of-line blocking: enq(3) arrives before enq(1);
    freeing 1 slot must NOT let enq(1) jump ahead. *)
let test_enqueuer_head_of_line_blocking () = failwith "TODO: implement"

(** Test that no items are lost or duplicated under concurrent access. *)
let test_no_lost_items () = failwith "TODO: implement"

(** Test that a batch enqueue is not interleaved with another batch. *)
let test_batch_atomicity () = failwith "TODO: implement"

(** Stress test: multiple producers and consumers with many operations. *)
let test_stress () = failwith "TODO: implement"

let () =
  test_sequential_basic ();
  test_error_handling ();
  test_blocking_enq_deq ();
  test_fifo_single_producer_consumer ();
  test_dequeuer_head_of_line_blocking ();
  test_enqueuer_head_of_line_blocking ();
  test_no_lost_items ();
  test_batch_atomicity ();
  test_stress ();
  printf "\nAll manual tests passed!\n"
