(* benchmark_queues.ml
 *
 * Throughput comparison: Bounded queue vs split-counter bounded queue
 * vs lock-free (Michael-Scott) queue.
 *
 * Half the domains are producers, half are consumers.  Each producer
 * enqueues [ops] items; each consumer dequeues until all items have
 * been consumed.  We measure total operations per second.
 *
 * Usage:
 *   dune exec test/benchmark_queues.exe [-- --ops N --runs N --max-threads N]
 *)

(* ----- Queue adapters ---------------------------------------------- *)

module type QUEUE = sig
  type 'a t
  val name : string
  val create : capacity:int -> int t
  val try_enq : int t -> int -> bool
  val try_deq : int t -> int option
end

module BoundedQ : QUEUE = struct
  type 'a t = 'a Bounded_queue.t
  let name = "Bounded"
  let create ~capacity = Bounded_queue.create capacity
  let try_enq q x = Bounded_queue.try_enq q x
  let try_deq q = Bounded_queue.try_deq q
end

module SplitQ : QUEUE = struct
  type 'a t = 'a Bounded_queue_split_counter.t
  let name = "SplitCtr"
  let create ~capacity = Bounded_queue_split_counter.create capacity
  let try_enq q x = Bounded_queue_split_counter.try_enq q x
  let try_deq q = Bounded_queue_split_counter.try_deq q
end

module LockFreeQ : QUEUE = struct
  type 'a t = 'a Lockfree_queue.t
  let name = "LockFree"
  let create ~capacity:_ = Lockfree_queue.create ()
  let try_enq q x = Lockfree_queue.enq q x; true
  let try_deq q = Lockfree_queue.try_deq q
end

(* ----- Benchmark --------------------------------------------------- *)

let benchmark (module Q : QUEUE) num_threads ops_per_producer =
  let num_producers = num_threads / 2 in
  let num_consumers = num_threads - num_producers in
  let num_producers = max num_producers 1 in
  let num_consumers = max num_consumers 1 in
  let total_items = num_producers * ops_per_producer in
  (* Capacity = total items so the queue never fills up.
     This ensures try_enq never fails due to a full queue,
     giving an apples-to-apples comparison with the unbounded
     lock-free queue. *)
  let q = Q.create ~capacity:total_items in

  let consumed = Atomic.make 0 in

  let producer () =
    for i = 1 to ops_per_producer do
      (* Spin until enqueue succeeds (bounded queue may be full) *)
      while not (Q.try_enq q i) do
        Domain.cpu_relax ()
      done
    done
  in

  let consumer () =
    while Atomic.get consumed < total_items do
      match Q.try_deq q with
      | Some _ -> ignore (Atomic.fetch_and_add consumed 1)
      | None -> Domain.cpu_relax ()
    done
  in

  Gc.full_major ();
  let t0 = Unix.gettimeofday () in
  let producers = List.init num_producers (fun _ -> Domain.spawn producer) in
  let consumers = List.init num_consumers (fun _ -> Domain.spawn consumer) in
  List.iter Domain.join producers;
  List.iter Domain.join consumers;
  let elapsed = Unix.gettimeofday () -. t0 in
  (* Total ops = enqueues + dequeues *)
  let total_ops = float_of_int (2 * total_items) in
  (elapsed, total_ops)

let avg lst =
  let sum = List.fold_left (+.) 0.0 lst in
  sum /. float_of_int (List.length lst)

let () =
  let ops = ref 100_000 in
  let runs = ref 5 in
  let max_threads = ref 8 in

  let speclist = [
    ("--ops", Arg.Set_int ops,
     "Enqueues per producer (default: 100000)");
    ("--runs", Arg.Set_int runs,
     "Number of runs to average (default: 5)");
    ("--max-threads", Arg.Set_int max_threads,
     "Maximum total threads (default: 8)");
  ] in
  Arg.parse speclist (fun _ -> ()) "Benchmark: Bounded vs Split-Counter vs Lock-Free Queue";

  Printf.printf "=== Queue Throughput Comparison ===\n\n%!";
  Printf.printf "Configuration: %d enqueues/producer × %d runs\n" !ops !runs;
  Printf.printf "Threads split evenly between producers and consumers\n\n%!";

  let queues : (module QUEUE) list = [
    (module BoundedQ);
    (module SplitQ);
    (module LockFreeQ);
  ] in

  Printf.printf "%-10s %14s %14s %14s\n%!"
    "Threads" "Bounded(Kops)" "SplitCtr(Kops)" "LockFree(Kops)";
  Printf.printf "%s\n%!" (String.make 56 '-');

  for threads = 2 to !max_threads do
    Printf.printf "%-10d" threads;
    List.iter (fun (module Q : QUEUE) ->
      let throughputs = List.init !runs (fun _ ->
        let elapsed, total_ops = benchmark (module Q) threads !ops in
        total_ops /. elapsed
      ) in
      let tp = avg throughputs in
      Printf.printf " %13.0fK" (tp /. 1000.0)
    ) queues;
    Printf.printf "\n%!";
  done;

  Printf.printf "\nThroughput in thousands of ops/sec (enqueues + dequeues).\n%!"
