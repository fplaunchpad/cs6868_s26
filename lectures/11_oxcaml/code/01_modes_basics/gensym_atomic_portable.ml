[@@@alert "-do_not_spawn_domains"]

(* The trick to making gensym portable: define it *inside* a function,
   not at the top level. Top-level let-bindings default to nonportable
   regardless of what they capture; function-local closures can be
   portable when their captures (Atomic.t mode-crosses) allow it. *)

let demo () =
  let count = Atomic.make 0 in
  let gensym prefix =
    let n = Atomic.fetch_and_add count 1 in
    prefix ^ "_" ^ string_of_int n
  in
  Domain.Safe.spawn (fun () -> gensym "x")

(* Compiles. Compare with gensym_atomic.ml: same Atomic.t-based body,
   but defined at the top level — the closure is nonportable and
   Domain.Safe.spawn rejects it.

   This isn't the *recommended* fix in OxCaml — capsules (Part 5) give
   you the same safety with a much cleaner API. It's shown here only
   to highlight that the rejection in gensym_atomic.ml is about scope,
   not about atomics. *)
