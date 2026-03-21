type state =
  | Initial
  | Waiting of (unit -> unit)
  | Signaled

type t = { mutable state : state }

type _ Effect.t += Await : t -> unit Effect.t

let create () = { state = Initial }

let signal t =
  match t.state with
  | Initial -> t.state <- Signaled; true
  | Waiting cb -> t.state <- Signaled; cb (); true
  | Signaled -> false

let on_signal t cb =
  match t.state with
  | Initial -> t.state <- Waiting cb; true
  | Signaled -> false
  | Waiting _ -> failwith "Trigger.on_signal: already waiting"

let await t = Effect.perform (Await t)
