[@@@alert "-do_not_spawn_domains"]

let gensym_atomic =
  let count = Atomic.make 0 in
  fun prefix ->
    let n = Atomic.fetch_and_add count 1 in
    prefix ^ "_" ^ string_of_int n

let _ = Domain.Safe.spawn (fun () -> gensym_atomic "x")

(* Same error as the unsafe version: Atomic.t mode-crosses contention
   but not portability — the closure still captures top-level mutable
   state, so it is nonportable. *)
