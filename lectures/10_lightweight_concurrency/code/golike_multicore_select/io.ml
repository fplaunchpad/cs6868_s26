(** Asynchronous IO for fibers.

    A dedicated system thread runs a {!Unix.select} loop and signals
    fiber-level {!Trigger.t} values when file descriptors become ready
    or timers expire.  Because the IO thread is a real OS thread, it
    can block in [Unix.select] without stalling the fiber scheduler.

    {b Precondition}: every [file_descr] passed to functions in this
    module {b must} already be in non-blocking mode ([Unix.set_nonblock]
    has been called on it).  All sockets returned by {!accept} are put
    into non-blocking mode automatically.

    When a fiber calls e.g. [Io.read fd buf pos len]:
    1. It attempts [Unix.read fd buf pos len] immediately.
    2. If the call succeeds (data was already buffered) it returns at once.
    3. If it raises [EAGAIN]/[EWOULDBLOCK], the fiber registers [fd] for
       read-readiness with the IO thread and suspends via [Trigger.await].
    4. The IO thread's [Unix.select] reports [fd] ready → signals the trigger.
    5. The fiber resumes and retries the syscall from step 1.

    The attempt-first pattern avoids an unnecessary suspend when data is
    already available, and the retry loop is correct even if readiness
    becomes stale between the notification and the syscall.

    A self-pipe (wakeup pipe) lets fiber-side registration poke the IO
    thread out of [Unix.select] so it picks up newly registered fds or
    timers immediately. *)

type file_descr = Unix.file_descr

type sockaddr = Unix.sockaddr

type msg_flag = Unix.msg_flag

(** Per-fd read/write trigger queues. *)
type fd_waiters = {
  rd : Trigger.t Queue.t;  (** fibers waiting for read-readiness  *)
  wr : Trigger.t Queue.t;  (** fibers waiting for write-readiness *)
}

(* All IO subsystem state lives in a single record.  The [mutex] and [cond]
   protect [fd_table] and [timers].  [started] gates lazy initialization of
   the IO thread via a double-checked lock. *)
type state = {
  mutex : Mutex.t;          (** protects all mutable fields below       *)
  cond : Condition.t;       (** IO thread waits here when idle          *)
  fd_table : (file_descr, fd_waiters) Hashtbl.t; (** fd → waiter queues *)
  timers : (float * Trigger.t) list ref; (** pending sleep deadlines    *)
  started : bool Atomic.t;  (** gates lazy IO thread creation           *)
  wakeup_r : file_descr;    (** self-pipe read end                      *)
  wakeup_w : file_descr;    (** self-pipe write end                     *)
}

let st =
  let rfd, wfd = Unix.pipe () in
  Unix.set_nonblock rfd;
  Unix.set_nonblock wfd;
  {
    mutex = Mutex.create ();
    cond = Condition.create ();
    fd_table = Hashtbl.create 32;
    timers = ref [];
    started = Atomic.make false;
    wakeup_r = rfd;
    wakeup_w = wfd;
  }

(** Signal every trigger in [q]. *)
let wake_all q =
  while not (Queue.is_empty q) do
    ignore (Trigger.signal (Queue.pop q) : bool)
  done

(** Return (or lazily create) the waiter queues for [fd]. *)
let get_fd_waiters fd =
  match Hashtbl.find_opt st.fd_table fd with
  | Some w -> w
  | None ->
      let w = { rd = Queue.create (); wr = Queue.create () } in
      Hashtbl.add st.fd_table fd w;
      w

(** Remove the fd entry from the table if both queues are empty. *)
let cleanup_fd_entry fd =
  match Hashtbl.find_opt st.fd_table fd with
  | Some w when Queue.is_empty w.rd && Queue.is_empty w.wr ->
      Hashtbl.remove st.fd_table fd
  | _ -> ()

(** Signal all timers whose deadline has passed. *)
let fire_due_timers_locked now =
  let due, pending = List.partition (fun (deadline, _) -> deadline <= now) !(st.timers) in
  st.timers := pending;
  List.iter (fun (_, t) -> ignore (Trigger.signal t : bool)) due

(** Compute the timeout for [Unix.select]: time until the earliest
    pending timer, or [-1.] (block forever) if there are none. *)
let timeout_locked now =
  match List.fold_left (fun acc (d, _) -> min acc d) infinity !(st.timers) with
  | t when t = infinity -> -1.
  | t -> max 0. (t -. now)

(** Collect file descriptors that have waiting readers/writers. *)
let ready_fds_locked () =
  Hashtbl.fold
    (fun fd w (racc, wacc) ->
      let racc = if Queue.is_empty w.rd then racc else fd :: racc in
      let wacc = if Queue.is_empty w.wr then wacc else fd :: wacc in
      (racc, wacc))
    st.fd_table
    ([], [])

(** Write one byte to the wakeup pipe to interrupt [Unix.select]. *)
let poke_wakeup () =
  (try ignore (Unix.write_substring st.wakeup_w "x" 0 1 : int)
   with Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK | Unix.EBADF), _, _) -> ())

(** Consume all bytes from the wakeup pipe so it doesn't keep
    triggering [Unix.select] as readable. *)
let drain_wakeup_fd rfd =
  let buf = Bytes.create 128 in
  let rec loop () =
    match Unix.read rfd buf 0 128 with
    | n when n > 0 -> loop ()
    | _ -> ()
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK | Unix.EBADF), _, _) -> ()
  in
  loop ()

(** After [Unix.select] returns, dispatch ready fds and fire timers.
    Called with [st.mutex] held. *)
let process_ready_locked wakeup_fd readable writable =
  if List.mem wakeup_fd readable then
    drain_wakeup_fd wakeup_fd;
  List.iter
    (fun fd ->
      if fd <> wakeup_fd then
        match Hashtbl.find_opt st.fd_table fd with
        | None -> ()
        | Some w ->
            wake_all w.rd;
            cleanup_fd_entry fd)
    readable;
  List.iter
    (fun fd ->
      match Hashtbl.find_opt st.fd_table fd with
      | None -> ()
      | Some w ->
          wake_all w.wr;
          cleanup_fd_entry fd)
    writable;
  fire_due_timers_locked (Unix.gettimeofday ())

(** The IO thread's main loop.  Blocks on [Condition.wait] when idle
    (no fds or timers registered), then loops over [Unix.select]. *)
let rec io_loop wakeup_fd =
  Mutex.lock st.mutex;
  while Hashtbl.length st.fd_table = 0 && !(st.timers) = [] do
    Condition.wait st.cond st.mutex
  done;
  fire_due_timers_locked (Unix.gettimeofday ());
  let now = Unix.gettimeofday () in
  let timeout = timeout_locked now in
  let readable, writable = ready_fds_locked () in
  Mutex.unlock st.mutex;

  let readable, writable =
    try
      let r, w, _ =
        Unix.select (wakeup_fd :: readable) writable [] timeout
      in
      (r, w)
    with Unix.Unix_error (Unix.EBADF, _, _) ->
      (* A monitored fd was closed.  Wake all its waiters so the fibers
         see the error, and remove the stale entry. *)
      Mutex.lock st.mutex;
      let stale =
        Hashtbl.fold (fun fd _ acc ->
          try ignore (Unix.fstat fd : Unix.stats); acc
          with Unix.Unix_error (Unix.EBADF, _, _) -> fd :: acc)
          st.fd_table []
      in
      List.iter (fun fd ->
        match Hashtbl.find_opt st.fd_table fd with
        | None -> ()
        | Some w -> wake_all w.rd; wake_all w.wr;
                    Hashtbl.remove st.fd_table fd)
        stale;
      Mutex.unlock st.mutex;
      ([], [])
  in

  Mutex.lock st.mutex;
  process_ready_locked wakeup_fd readable writable;
  Mutex.unlock st.mutex;
  io_loop wakeup_fd

(** Lazily start the IO thread.
    Uses the {b double-checked locking} pattern for one-time initialisation:

    {[
      if not (fast atomic check) then begin   (* 1st check — no lock *)
        lock mutex;
        if not (fast atomic check) then begin (* 2nd check — under lock *)
          do_init ();
          atomic_set flag true
        end;
        unlock mutex
      end
    ]}

    - The first check (no lock) is the {e fast path}: once initialised, no
      lock is ever acquired, making repeated calls to [ensure_started] cheap.
    - The mutex serialises concurrent callers so [Thread.create] is called
      exactly once.
    - The second check is necessary: between the first check and acquiring
      the lock, another thread may have already completed initialisation.
    - The flag must be an {!Atomic.t} (or otherwise sequentially consistent)
      so that the first check is not reordered or cached by the compiler or
      hardware across the lock boundary.  A plain [ref bool] would be a data
      race under the OCaml memory model. *)
let ensure_started () =
  if not (Atomic.get st.started) then begin
    Mutex.lock st.mutex;
    if not (Atomic.get st.started) then begin
      (* ^^ Double-check locking *)
      ignore (Thread.create io_loop st.wakeup_r : Thread.t);
      Atomic.set st.started true
    end;
    Mutex.unlock st.mutex
  end

(* ----- Internal: wait for fd readiness ----- *)

(** [wait_readable fd] suspends the current fiber until [fd] is readable. *)
let wait_readable fd =
  ensure_started ();
  let trigger = Trigger.create () in
  Mutex.lock st.mutex;
  let w = get_fd_waiters fd in
  Queue.push trigger w.rd;
  Condition.signal st.cond;
  poke_wakeup ();
  Mutex.unlock st.mutex;
  Trigger.await trigger

(** [wait_writable fd] suspends the current fiber until [fd] is writable. *)
let wait_writable fd =
  ensure_started ();
  let trigger = Trigger.create () in
  Mutex.lock st.mutex;
  let w = get_fd_waiters fd in
  Queue.push trigger w.wr;
  Condition.signal st.cond;
  poke_wakeup ();
  Mutex.unlock st.mutex;
  Trigger.await trigger

(* ----- Public API ----- *)

let sleep delay =
  if delay <= 0. then ()
  else begin
    ensure_started ();
    let trigger = Trigger.create () in
    let deadline = Unix.gettimeofday () +. delay in
    Mutex.lock st.mutex;
    st.timers := (deadline, trigger) :: !(st.timers);
    Condition.signal st.cond;
    poke_wakeup ();
    Mutex.unlock st.mutex;
    Trigger.await trigger
  end

let read fd buf pos len =
  let rec loop () =
    match Unix.read fd buf pos len with
    | n -> n
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
        wait_readable fd; loop ()
  in
  loop ()

let write fd buf pos len =
  let rec loop () =
    match Unix.write fd buf pos len with
    | n -> n
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
        wait_writable fd; loop ()
  in
  loop ()

let recv fd buf pos len flags =
  let rec loop () =
    match Unix.recv fd buf pos len flags with
    | n -> n
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
        wait_readable fd; loop ()
  in
  loop ()

let send fd buf pos len flags =
  let rec loop () =
    match Unix.send fd buf pos len flags with
    | n -> n
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
        wait_writable fd; loop ()
  in
  loop ()

let accept fd =
  let rec loop () =
    match Unix.accept ~cloexec:true fd with
    | (cfd, addr) -> Unix.set_nonblock cfd; (cfd, addr)
    | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
        wait_readable fd; loop ()
  in
  loop ()

let connect fd addr =
  try Unix.connect fd addr with
  | Unix.Unix_error ((Unix.EINPROGRESS | Unix.EINTR), _, _) ->
      wait_writable fd;
      (match Unix.getsockopt_error fd with
       | None -> ()
       | Some err -> raise (Unix.Unix_error (err, "connect", "")))
