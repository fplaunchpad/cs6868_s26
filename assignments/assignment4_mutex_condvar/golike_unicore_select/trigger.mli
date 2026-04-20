(** A one-shot signaling primitive for cooperative scheduling.

    A trigger is a simple state machine:
    {v
      Initialized ──signal──> Signaled
         │
      on_signal(cb)
         │
         v
      Waiting(cb) ──signal──> Signaled (callback invoked)
    v} *)

type t

val create : unit -> t
(** Create a new trigger in the Initialized state. *)

val signal : t -> bool
(** Signal the trigger. Returns [true] on the first signal, [false] if
    already signaled. If a callback was registered via [on_signal],
    it is invoked. *)

val on_signal : t -> (unit -> unit) -> bool
(** [on_signal t cb] registers [cb] to be called when [t] is signaled.
    Returns [true] if the callback was registered (trigger was Initialized),
    or [false] if the trigger was already signaled.
    @raise Failure if a callback is already registered. *)

val await : t -> unit
(** Suspend the current fiber until the trigger is signaled.
    Performs the [Await] effect, which must be handled by a scheduler. *)

type _ Effect.t += Await : t -> unit Effect.t
(** The effect performed by [await]. *)
