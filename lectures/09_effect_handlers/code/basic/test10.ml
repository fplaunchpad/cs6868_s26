type _ Effect.t += E : 'c -> 'd Effect.t
                 | F : 'e -> 'f Effect.t

match e (* e: 'a *) with
| x (* x: 'a *) -> f x (* f: 'a -> 'b; f x: 'b *)
| exception e (* e: exn *) -> g e (* g: exn -> 'b; g e: 'b *)
| effect E v (* v: 'c; E v : 'd Effect.t *), k (* ('d,'b) continuation *)
    -> h v k (* h: 'c -> ('d,'b) continuation -> 'b; h v k: 'b *)
| effect F v (* v: 'e; F v : 'f Effect.t *), k (* ('f,'b) continuation *)
    -> i v k (* i: 'e -> ('f,'b) continuation -> 'b; i v k: 'b *)