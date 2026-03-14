(** QCheck-Lin Linearizability Test for LockFreeStack (builtin list version)

    == Expected Result ==
    This test should PASS.
*)

module LFS = Lockfree_stack_builtin_list

module LFSSig = struct
  type t = int LFS.t

  let init () = LFS.create ()
  let cleanup _ = ()

  open Lin

  let int_small = nat_small

  let api =
    [ val_ "push"    LFS.push    (t @-> int_small @-> returning unit);
      val_ "try_pop" LFS.try_pop (t @-> returning (option int));
      val_ "pop"     LFS.pop     (t @-> returning_or_exc int); ]
end

module LFS_domain = Lin_domain.Make(LFSSig)

let () =
  QCheck_base_runner.run_tests_main [
    LFS_domain.lin_test ~count:500
      ~name:"LockFreeStack (builtin list) linearizability";
  ]
