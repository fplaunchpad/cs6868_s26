type 'a t = 'a Ivar.t

let async f =
  let p = Ivar.create () in
  Sched.fork (fun () -> Ivar.fill p (f ()));
  p

let await p = Ivar.read p
