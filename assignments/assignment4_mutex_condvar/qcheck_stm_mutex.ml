(** QCheck-STM sequential state-machine test for the fiber-level Mutex.

    Tests the non-blocking operations ([try_lock], [unlock]) against a
    simple boolean model (state = "is the mutex currently locked?").
    Only sequential mode is used — concurrent mode would require
    multiple Domains, which conflict with the unicore fiber scheduler.
*)

open QCheck
open STM

type cmd =
  | Try_lock
  | Unlock

let show_cmd = function
  | Try_lock -> "Try_lock"
  | Unlock   -> "Unlock"

let arb_cmd _state =
  QCheck.make ~print:show_cmd
    (Gen.oneof [ Gen.return Try_lock; Gen.return Unlock ])

(** Model state: [true] iff the mutex is currently held. *)
let next_state cmd state =
  match cmd with
  | Try_lock -> if state then state else true   (* succeeds iff was unlocked *)
  | Unlock   -> false

(** [Unlock] is only valid when the mutex is actually held; otherwise
    our implementation raises.  Filter out invalid commands. *)
let precond cmd state =
  match cmd with
  | Try_lock -> true
  | Unlock   -> state

let run cmd sut =
  match cmd with
  | Try_lock -> Res (bool, Mutex.try_lock sut)
  | Unlock   -> Res (unit, Mutex.unlock sut)

let postcond cmd state result =
  match cmd, result with
  | Try_lock, Res ((Bool, _), acquired) ->
    (* Should succeed iff the mutex was not held *)
    acquired = (not state)
  | Unlock, Res ((Unit, _), ()) -> true
  | _, _ -> false

module Spec = struct
  type sut = Mutex.t
  type state = bool
  type nonrec cmd = cmd

  let arb_cmd = arb_cmd
  let init_state = false
  let next_state = next_state
  let precond = precond
  let run = run
  let init_sut () = Mutex.create ()
  let cleanup _ = ()
  let postcond = postcond
  let show_cmd = show_cmd
end

module Seq = STM_sequential.Make(Spec)

let () =
  Printf.printf "Running sequential STM test on Mutex...\n\n%!";
  let seq_test = Seq.agree_test ~count:1000 ~name:"Mutex sequential" in
  exit (QCheck_base_runner.run_tests ~verbose:true [seq_test])
