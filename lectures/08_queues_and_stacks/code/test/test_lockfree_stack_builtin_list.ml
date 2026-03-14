(** Test suite for LockFreeStack (builtin list version) *)

let test_sequential () =
  Printf.printf "Testing sequential operations...\n%!";
  let s = Lockfree_stack_builtin_list.create () in

  (* Empty stack *)
  assert (Lockfree_stack_builtin_list.try_pop s = None);

  (* Push and pop *)
  Lockfree_stack_builtin_list.push s 1;
  Lockfree_stack_builtin_list.push s 2;
  Lockfree_stack_builtin_list.push s 3;

  (* LIFO order *)
  assert (Lockfree_stack_builtin_list.try_pop s = Some 3);
  assert (Lockfree_stack_builtin_list.try_pop s = Some 2);
  assert (Lockfree_stack_builtin_list.try_pop s = Some 1);

  (* Empty again *)
  assert (Lockfree_stack_builtin_list.try_pop s = None);

  (* Test pop raising Empty *)
  (try ignore (Lockfree_stack_builtin_list.pop s); assert false
   with Lockfree_stack_builtin_list.Empty -> ());

  Printf.printf "Sequential tests passed!\n%!"

let test_interleaved () =
  Printf.printf "Testing interleaved push/pop...\n%!";
  let s = Lockfree_stack_builtin_list.create () in

  Lockfree_stack_builtin_list.push s 10;
  assert (Lockfree_stack_builtin_list.try_pop s = Some 10);

  Lockfree_stack_builtin_list.push s 20;
  Lockfree_stack_builtin_list.push s 30;
  assert (Lockfree_stack_builtin_list.try_pop s = Some 30);

  Lockfree_stack_builtin_list.push s 40;
  assert (Lockfree_stack_builtin_list.try_pop s = Some 40);
  assert (Lockfree_stack_builtin_list.try_pop s = Some 20);

  assert (Lockfree_stack_builtin_list.try_pop s = None);

  Printf.printf "Interleaved tests passed!\n%!"

let test_single_element () =
  Printf.printf "Testing single-element cycles...\n%!";
  let s = Lockfree_stack_builtin_list.create () in
  for i = 0 to 99 do
    Lockfree_stack_builtin_list.push s i;
    assert (Lockfree_stack_builtin_list.try_pop s = Some i);
    assert (Lockfree_stack_builtin_list.try_pop s = None)
  done;
  Printf.printf "Single-element tests passed!\n%!"

let test_fill_and_drain () =
  Printf.printf "Testing fill and drain...\n%!";
  let n = 1000 in
  let s = Lockfree_stack_builtin_list.create () in

  for i = 0 to n - 1 do
    Lockfree_stack_builtin_list.push s i
  done;

  (* LIFO: drain in reverse order *)
  for i = n - 1 downto 0 do
    assert (Lockfree_stack_builtin_list.try_pop s = Some i)
  done;
  assert (Lockfree_stack_builtin_list.try_pop s = None);

  Printf.printf "Fill and drain tests passed!\n%!"

let test_concurrent () =
  Printf.printf "Testing concurrent operations...\n%!";
  let s = Lockfree_stack_builtin_list.create () in
  let num_producers = 4 in
  let num_consumers = 4 in
  let items_per_producer = 1000 in
  let total_items = num_producers * items_per_producer in

  let seen = Array.make total_items false in
  let seen_lock = Mutex.create () in

  let producer id =
    let start = id * items_per_producer in
    for i = start to start + items_per_producer - 1 do
      Lockfree_stack_builtin_list.push s i
    done
  in

  let consumed = Atomic.make 0 in
  let consumer () =
    while Atomic.get consumed < total_items do
      match Lockfree_stack_builtin_list.try_pop s with
      | Some v ->
        Mutex.lock seen_lock;
        seen.(v) <- true;
        Mutex.unlock seen_lock;
        ignore (Atomic.fetch_and_add consumed 1)
      | None ->
        Domain.cpu_relax ()
    done
  in

  let producers = Array.init num_producers (fun id ->
    Domain.spawn (fun () -> producer id)
  ) in
  let consumers = Array.init num_consumers (fun _ ->
    Domain.spawn (fun () -> consumer ())
  ) in

  Array.iter Domain.join producers;
  Array.iter Domain.join consumers;

  for i = 0 to total_items - 1 do
    if not seen.(i) then
      Printf.printf "MISSING item %d\n%!" i;
    assert seen.(i)
  done;

  Printf.printf "Concurrent tests passed!\n%!"

let () =
  Printf.printf "=== LockFreeStack (builtin list) Tests ===\n\n%!";
  test_sequential ();
  test_interleaved ();
  test_single_element ();
  test_fill_and_drain ();
  test_concurrent ();
  Printf.printf "\nAll tests passed!\n%!"
