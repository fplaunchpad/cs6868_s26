(* benchmark_stacks.ml
 *
 * Throughput comparison: Treiber stack vs Elimination backoff stack.
 *
 * Each domain does a balanced mix of push/pop operations on a shared
 * stack.  We measure total operations per second as the domain count
 * increases.  Under high contention the elimination backoff stack
 * should maintain (or improve) throughput because complementary
 * push/pop pairs can eliminate without touching the shared top pointer.
 *
 * Usage:
 *   dune exec test/benchmark_stacks.exe [-- --ops N --runs N --max-threads N]
 *)

let benchmark_treiber num_threads ops_per_thread =
  let s = Lockfree_stack_builtin_list.create () in
  (* Pre-fill so pops don't always see empty *)
  for i = 1 to 100 do
    Lockfree_stack_builtin_list.push s i
  done;

  let thread_work () =
    for i = 1 to ops_per_thread do
      if i mod 2 = 0 then
        Lockfree_stack_builtin_list.push s i
      else
        ignore (Lockfree_stack_builtin_list.try_pop s)
    done
  in

  Gc.full_major ();
  let t0 = Unix.gettimeofday () in
  let domains = List.init num_threads (fun _ -> Domain.spawn thread_work) in
  List.iter Domain.join domains;
  Unix.gettimeofday () -. t0

let benchmark_elimination num_threads ops_per_thread =
  let s = Elimination_backoff_stack.create () in
  (* Pre-fill *)
  for i = 1 to 100 do
    Elimination_backoff_stack.push s i
  done;

  let thread_work () =
    for i = 1 to ops_per_thread do
      if i mod 2 = 0 then
        Elimination_backoff_stack.push s i
      else
        ignore (Elimination_backoff_stack.try_pop s)
    done
  in

  Gc.full_major ();
  let t0 = Unix.gettimeofday () in
  let domains = List.init num_threads (fun _ -> Domain.spawn thread_work) in
  List.iter Domain.join domains;
  Unix.gettimeofday () -. t0

let avg times =
  let sum = List.fold_left (+.) 0.0 times in
  sum /. float_of_int (List.length times)

let () =
  let ops = ref 100_000 in
  let runs = ref 5 in
  let max_threads = ref 8 in

  let speclist = [
    ("--ops", Arg.Set_int ops,
     "Operations per thread (default: 100000)");
    ("--runs", Arg.Set_int runs,
     "Number of runs to average (default: 5)");
    ("--max-threads", Arg.Set_int max_threads,
     "Maximum number of threads (default: 8)");
  ] in
  Arg.parse speclist (fun _ -> ()) "Benchmark: Treiber vs Elimination Backoff Stack";

  Printf.printf "=== Stack Throughput Comparison ===\n\n%!";
  Printf.printf "Configuration: %d ops/thread (50%% push, 50%% pop) × %d runs\n\n%!"
    !ops !runs;

  Printf.printf "%-10s %14s %14s %10s\n%!"
    "Threads" "Treiber(Mops)" "Elim(Mops)" "Speedup";
  Printf.printf "%s\n%!" (String.make 52 '-');

  for threads = 1 to !max_threads do
    let total_ops = float_of_int (threads * !ops) in

    let treiber_times = List.init !runs (fun _ ->
      let t = benchmark_treiber threads !ops in
      Gc.full_major (); t
    ) in
    let treiber_tp = total_ops /. avg treiber_times in

    let elim_times = List.init !runs (fun _ ->
      let t = benchmark_elimination threads !ops in
      Gc.full_major (); t
    ) in
    let elim_tp = total_ops /. avg elim_times in

    let speedup = elim_tp /. treiber_tp in

    Printf.printf "%-10d %13.1fM %13.1fM %9.2fx\n%!"
      threads
      (treiber_tp /. 1e6)
      (elim_tp /. 1e6)
      speedup
  done;

  Printf.printf "\nThroughput in millions of ops/sec. Speedup > 1 favours elimination.\n%!"
