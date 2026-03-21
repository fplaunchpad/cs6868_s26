open Effect

type toss = Heads | Tails

type _ Effect.t += Choose : bool Effect.t
type _ Effect.t += Fail : 'a Effect.t

let choose () = perform Choose
let fail () = perform Fail

let toss () =
  if choose () then Heads else Tails

(* A drunk person tosses a coin but might fail to catch it. *)
let drunk_toss () =
  if choose () then toss ()
  else fail ()

(* ------------------------------------------------------------ *)
(* Handler: all_results — enumerates the sample space            *)
(* Uses Multicont to clone the continuation (multi-shot).        *)
(* ------------------------------------------------------------ *)

let all_results f =
  match f () with
  | x -> [x]
  | effect Choose, k ->
      let open Multicont.Deep in
      let r = promote k in
      resume r true @ resume r false

(* ------------------------------------------------------------ *)
(* Handler: maybe_result — returns None on Fail                  *)
(* ------------------------------------------------------------ *)

let maybe_result f =
  match f () with
  | x -> Some x
  | effect Fail, k ->
      Multicont.Deep.drop_continuation k;
      None

let string_of_toss = function Heads -> "Heads" | Tails -> "Tails"

let () =
  (* #1: all_results(toss) = [Heads; Tails] *)
  let results = all_results toss in
  Printf.printf "all_results(toss): [%s]\n"
    (String.concat "; " (List.map string_of_toss results));

  (* #2: all_results(toss twice) = all 4 combinations *)
  let toss_twice () = (toss (), toss ()) in
  let results = all_results toss_twice in
  Printf.printf "all_results(toss_twice): [%s]\n"
    (String.concat "; "
      (List.map (fun (a, b) ->
        "(" ^ string_of_toss a ^ ", " ^ string_of_toss b ^ ")") results));

  (* #3: all_results(maybe_result(drunk_toss)) = [Some Heads; Some Tails; None] *)
  let results = all_results (fun () -> maybe_result drunk_toss) in
  Printf.printf "all_results(maybe_result(drunk_toss)): [%s]\n"
    (String.concat "; "
      (List.map (function
        | Some t -> "Some " ^ string_of_toss t
        | None -> "None") results))

(* Output:
   all_results(toss): [Heads; Tails]
   all_results(toss_twice): [(Heads, Heads); (Tails, Heads); (Heads, Tails); (Tails, Tails)]
   all_results(maybe_result(drunk_toss)): [Some Heads; Some Tails; None]
*)
