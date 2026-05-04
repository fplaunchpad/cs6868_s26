[@@@alert "-do_not_spawn_domains"]

let gensym =
  let count = ref 0 in
  fun prefix ->
    count := !count + 1;
    prefix ^ "_" ^ string_of_int !count

let _ = Domain.Safe.spawn (fun () -> gensym "x")

(* Error: The value gensym is nonportable but is expected to be portable
          because it is used inside the function at Line ...
          which is expected to be portable. *)
