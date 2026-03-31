(** QCheck-Lin Linearizability Test for Batch Bounded Blocking Queue

    This test verifies that the non-blocking try_enq/try_deq operations
    are linearizable under concurrent access.

    == Your Task ==

    Complete the BatchQueueSig module below:
    1. Define wrapper functions for batch operations with fixed sizes
    2. Define the [api] list using Lin's DSL ([val_] combinator)

    == Design Note ==

    try_enq takes an int array argument and try_deq returns int array option.
    The Lin DSL works best with primitive types, so we define wrapper functions
    for small fixed batch sizes (1, 2, 3) and register each as a separate
    operation. This tests the core batch logic with manageable complexity.

    == Expected Result ==

    This test should PASS. The mutex-based implementation ensures all
    operations are linearizable.
*)

module BQ = BatchQueue

(** Lin API specification for the batch queue *)
module BatchQueueSig = struct
  type t = int BQ.t

  let init () = BQ.create 6

  let cleanup _ = ()

  open Lin
  let int_small = nat_small
  let _ = (t, int_small)
  let api = failwith "TODO: define wrapper functions and api list (see README Part 3)"
end

(** Generate the linearizability test from the specification *)
module BQ_domain = Lin_domain.Make(BatchQueueSig)

(** Run 1000 test iterations *)
let () =
  QCheck_base_runner.run_tests_main [
    BQ_domain.lin_test ~count:1000 ~name:"Batch queue linearizability";
  ]
