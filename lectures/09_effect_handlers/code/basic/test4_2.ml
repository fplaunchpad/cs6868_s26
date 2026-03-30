open Effect
open Effect.Deep

type _ Effect.t += E : string t
                 | F : string t

let comp n e =
  Printf.printf "%d " n;
  print_string (perform e);
  Printf.printf "%d " (n+3)

(* The numbers are printed in order from 0 to 9 *)
let main () =
  try
    comp 0 E; comp 4 F
  with
  | effect E, k ->
    print_string "1 ";
    continue k "2 ";
    print_string "9 "
  | effect F, k ->
    print_string "5 ";
    continue k "6 ";
    print_string "8 "

let () = main ()
