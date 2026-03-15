(** Test suite for EliminationBackoffStack *)

let test_sequential () =
  Printf.printf "Testing sequential operations...\n%!";
  let s = Elimination_backoff_stack.create () in

  (* Empty stack *)
  assert (Elimination_backoff_stack.try_pop s = None);

  (* Push and pop *)
  Elimination_backoff_stack.push s 1;
  Elimination_backoff_stack.push s 2;
  Elimination_backoff_stack.push s 3;

  (* LIFO order *)
  assert (Elimination_backoff_stack.try_pop s = Some 3);
  assert (Elimination_backoff_stack.try_pop s = Some 2);
  assert (Elimination_backoff_stack.try_pop s = Some 1);

  (* Empty again *)
  assert (Elimination_backoff_stack.try_pop s = None);

  Printf.printf "Sequential tests passed!\n%!"

let test_interleaved () =
  Printf.printf "Testing interleaved push/pop...\n%!";
  let s = Elimination_backoff_stack.create () in

  Elimination_backoff_stack.push s 10;
  assert (Elimination_backoff_stack.try_pop s = Some 10);

  Elimination_backoff_stack.push s 20;
  Elimination_backoff_stack.push s 30;
  assert (Elimination_backoff_stack.try_pop s = Some 30);

  Elimination_backoff_stack.push s 40;
  assert (Elimination_backoff_stack.try_pop s = Some 40);
  assert (Elimination_backoff_stack.try_pop s = Some 20);

  assert (Elimination_backoff_stack.try_pop s = None);

  Printf.printf "Interleaved tests passed!\n%!"

let test_single_element () =
  Printf.printf "Testing single-element cycles...\n%!";
  let s = Elimination_backoff_stack.create () in
  for i = 0 to 99 do
    Elimination_backoff_stack.push s i;
    assert (Elimination_backoff_stack.try_pop s = Some i);
    assert (Elimination_backoff_stack.try_pop s = None)
  done;
  Printf.printf "Single-element tests passed!\n%!"

let test_fill_and_drain () =
  Printf.printf "Testing fill and drain...\n%!";
  let n = 1000 in
  let s = Elimination_backoff_stack.create () in

  for i = 0 to n - 1 do
    Elimination_backoff_stack.push s i
  done;

  (* LIFO: drain in reverse order *)
  for i = n - 1 downto 0 do
    assert (Elimination_backoff_stack.try_pop s = Some i)
  done;
  assert (Elimination_backoff_stack.try_pop s = None);

  Printf.printf "Fill and drain tests passed!\n%!"

let test_concurrent () =
  Printf.printf "Testing concurrent operations...\n%!";
  let s = Elimination_backoff_stack.create () in
  let num_producers = 4 in
  let num_consumers = 4 in
  let items_per_producer = 1000 in
  let total_items = num_producers * items_per_producer in

  (* Track which items were popped *)
  let seen = Array.make total_items false in
  let seen_lock = Mutex.create () in

  (* Producer: push items in its range *)
  let producer id =
    let start = id * items_per_producer in
    for i = start to start + items_per_producer - 1 do
      Elimination_backoff_stack.push s i
    done
  in

  (* Consumer: pop items until all consumed *)
  let consumed = Atomic.make 0 in
  let consumer () =
    while Atomic.get consumed < total_items do
      match Elimination_backoff_stack.try_pop s with
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
  Printf.printf "=== EliminationBackoffStack Tests ===\n\n%!";
  test_sequential ();
  test_interleaved ();
  test_single_element ();
  test_fill_and_drain ();
  test_concurrent ();
  Printf.printf "\nAll tests passed!\n%!"
