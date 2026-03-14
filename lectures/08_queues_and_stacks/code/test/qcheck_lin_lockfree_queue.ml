(** QCheck-Lin Linearizability Test for LockFreeQueue

    This test verifies that the lock-free queue is linearizable
    under concurrent access. The Michael-Scott algorithm should
    be linearizable by design.

    == Expected Result ==

    This test should PASS. The CAS-based design ensures
    linearizability without locks.
*)

module LFQ = Lockfree_queue

(** Lin API specification for the lock-free queue. *)
module LFQSig = struct
  type t = int LFQ.t

  let init () = LFQ.create ()

  let cleanup _ = ()

  open Lin

  let int_small = nat_small

  (** API: enq always succeeds (returns unit), try_deq may return None *)
  let api =
    [ val_ "enq"     LFQ.enq     (t @-> int_small @-> returning unit);
      val_ "try_deq" LFQ.try_deq (t @-> returning (option int)); ]
end

module LFQ_domain = Lin_domain.Make(LFQSig)

let () =
  QCheck_base_runner.run_tests_main [
    LFQ_domain.lin_test ~count:500 ~name:"LockFreeQueue linearizability";
  ]
