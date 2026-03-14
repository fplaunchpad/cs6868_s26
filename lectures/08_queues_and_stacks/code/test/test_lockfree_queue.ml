(** Test suite for LockFreeQueue *)

let test_sequential () =
  Printf.printf "Testing sequential operations...\n%!";
  let q = Lockfree_queue.create () in

  (* Empty queue *)
  assert (Lockfree_queue.try_deq q = None);

  (* Enqueue and dequeue *)
  Lockfree_queue.enq q 1;
  Lockfree_queue.enq q 2;
  Lockfree_queue.enq q 3;

  (* FIFO order *)
  assert (Lockfree_queue.try_deq q = Some 1);
  assert (Lockfree_queue.try_deq q = Some 2);
  assert (Lockfree_queue.try_deq q = Some 3);

  (* Empty again *)
  assert (Lockfree_queue.try_deq q = None);

  Printf.printf "Sequential tests passed!\n%!"

let test_interleaved () =
  Printf.printf "Testing interleaved enq/deq...\n%!";
  let q = Lockfree_queue.create () in

  Lockfree_queue.enq q 10;
  assert (Lockfree_queue.try_deq q = Some 10);

  Lockfree_queue.enq q 20;
  Lockfree_queue.enq q 30;
  assert (Lockfree_queue.try_deq q = Some 20);

  Lockfree_queue.enq q 40;
  assert (Lockfree_queue.try_deq q = Some 30);
  assert (Lockfree_queue.try_deq q = Some 40);

  assert (Lockfree_queue.try_deq q = None);

  Printf.printf "Interleaved tests passed!\n%!"

let test_single_element () =
  Printf.printf "Testing single-element cycles...\n%!";
  let q = Lockfree_queue.create () in
  for i = 0 to 99 do
    Lockfree_queue.enq q i;
    assert (Lockfree_queue.try_deq q = Some i);
    assert (Lockfree_queue.try_deq q = None)
  done;
  Printf.printf "Single-element tests passed!\n%!"

let test_fill_and_drain () =
  Printf.printf "Testing fill and drain...\n%!";
  let n = 1000 in
  let q = Lockfree_queue.create () in

  for i = 0 to n - 1 do
    Lockfree_queue.enq q i
  done;

  for i = 0 to n - 1 do
    assert (Lockfree_queue.try_deq q = Some i)
  done;
  assert (Lockfree_queue.try_deq q = None);

  Printf.printf "Fill and drain tests passed!\n%!"

let test_concurrent () =
  Printf.printf "Testing concurrent operations...\n%!";
  let q = Lockfree_queue.create () in
  let num_producers = 4 in
  let num_consumers = 4 in
  let items_per_producer = 1000 in
  let total_items = num_producers * items_per_producer in

  (* Track which items were dequeued *)
  let seen = Array.make total_items false in
  let seen_lock = Mutex.create () in

  (* Producer: enqueue items in its range *)
  let producer id =
    let start = id * items_per_producer in
    for i = start to start + items_per_producer - 1 do
      Lockfree_queue.enq q i
    done
  in

  (* Consumer: dequeue items until all consumed *)
  let consumed = Atomic.make 0 in
  let consumer () =
    while Atomic.get consumed < total_items do
      match Lockfree_queue.try_deq q with
      | Some v ->
        Mutex.lock seen_lock;
        seen.(v) <- true;
        Mutex.unlock seen_lock;
        ignore (Atomic.fetch_and_add consumed 1)
      | None ->
        Domain.cpu_relax ()
    done
  in

  (* Spawn producers and consumers *)
  let producers = Array.init num_producers (fun id ->
    Domain.spawn (fun () -> producer id)
  ) in
  let consumers = Array.init num_consumers (fun _ ->
    Domain.spawn (fun () -> consumer ())
  ) in

  Array.iter Domain.join producers;
  Array.iter Domain.join consumers;

  (* Verify all items were seen *)
  for i = 0 to total_items - 1 do
    if not seen.(i) then
      Printf.printf "MISSING item %d\n%!" i;
    assert seen.(i)
  done;

  Printf.printf "Concurrent tests passed!\n%!"

let () =
  Printf.printf "=== LockFreeQueue Tests ===\n\n%!";
  test_sequential ();
  test_interleaved ();
  test_single_element ();
  test_fill_and_drain ();
  test_concurrent ();
  Printf.printf "\nAll tests passed!\n%!"
