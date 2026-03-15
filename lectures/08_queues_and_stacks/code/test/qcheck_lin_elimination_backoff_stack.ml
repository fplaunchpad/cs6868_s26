(** QCheck-Lin Linearizability Test for EliminationBackoffStack

    This test verifies that the elimination backoff stack is
    linearizable under concurrent access.

    == Expected Result ==

    This test should PASS.  Both the Treiber-stack path and the
    elimination path preserve linearizability.
*)

module EBS = Elimination_backoff_stack

(** Lin API specification for the elimination backoff stack. *)
module EBSSig = struct
  type t = int EBS.t

  let init () = EBS.create ()

  let cleanup _ = ()

  open Lin

  let int_small = nat_small

  let api =
    [ val_ "push"    EBS.push    (t @-> int_small @-> returning unit);
      val_ "try_pop" EBS.try_pop (t @-> returning (option int));
      val_ "pop"     EBS.pop     (t @-> returning_or_exc int); ]
end

module EBS_domain = Lin_domain.Make(EBSSig)

let () =
  QCheck_base_runner.run_tests_main [
    EBS_domain.lin_test ~count:500 ~name:"EliminationBackoffStack linearizability";
  ]
