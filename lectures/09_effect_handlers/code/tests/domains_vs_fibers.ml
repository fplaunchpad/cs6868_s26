open Sched_basic

(* Benchmark: Domain spawn-join vs lightweight threads *)

let pp_int n =
  let s = string_of_int n in
  let len = String.length s in
  let buf = Buffer.create (len + len / 3) in
  String.iteri (fun i c ->
    if i > 0 && (len - i) mod 3 = 0 then Buffer.add_char buf ',';
    Buffer.add_char buf c
  ) s;
  Buffer.contents buf

let time_it label f =
  let t0 = Unix.gettimeofday () in
  f ();
  let t1 = Unix.gettimeofday () in
  let elapsed = t1 -. t0 in
  Printf.printf "%s: %.3f s\n" label elapsed;
  elapsed

let n_light = 50_000_000
let n_domain = 50_000

let () =
  (* Lightweight threads via effect handler scheduler *)
  let t_light = time_it
    (Printf.sprintf "Lightweight threads (%s)" (pp_int n_light))
    (fun () ->
      run (fun () ->
        for _ = 1 to n_light do
          fork (fun () -> ())
        done))
  in

  (* Domain spawn-join *)
  let t_domain = time_it
    (Printf.sprintf "Domain spawn+join   (%s)" (pp_int n_domain))
    (fun () ->
      for _ = 1 to n_domain do
        Domain.join (Domain.spawn (fun () -> ()))
      done)
  in

  let throughput_light = Float.of_int n_light /. t_light in
  let throughput_domain = Float.of_int n_domain /. t_domain in
  Printf.printf "\nThroughput:\n";
  Printf.printf "  Lightweight: %s threads/s\n" (pp_int (int_of_float throughput_light));
  Printf.printf "  Domains:     %s spawn-joins/s\n" (pp_int (int_of_float throughput_domain));
  Printf.printf "  Ratio:       %.1fx\n" (throughput_light /. throughput_domain)
