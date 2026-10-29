(** DSCheck tests for the lock-free list.

    DSCheck can only explore interleavings of atomic operations it can
    see, so the list under test is [Lockfree_list.Make] instantiated with
    [Dscheck.TracedAtomic]: every read and CAS inside [add], [remove] and
    [contains] becomes a scheduling point.  [Atomic.trace] then runs the
    test body once for every (non-equivalent) interleaving of the spawned
    threads, and [Atomic.check] fails if the property is violated in any
    of them, printing the offending interleaving. *)

module Atomic = Dscheck.TracedAtomic
module L = Lockfree_list.Make (Atomic)

(* Test 1: two concurrent adds of the same element.
   The list holds no duplicates, so exactly one add succeeds. *)
let two_adds_same_element (module L : Lockfree_list.S) () =
  Atomic.trace (fun () ->
    let l = L.create () in
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in
    Atomic.spawn (fun () -> Atomic.set r1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set r2 (L.add l 1));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let a = Atomic.get r1 and b = Atomic.get r2 in
        a <> b && L.contains l 1)))

(* Test 2: two concurrent adds of distinct elements.
   Both succeed and both elements end up in the list (no lost add). *)
let two_adds_distinct_elements (module L : Lockfree_list.S) () =
  Atomic.trace (fun () ->
    let l = L.create () in
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in
    Atomic.spawn (fun () -> Atomic.set r1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set r2 (L.add l 2));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        Atomic.get r1 && Atomic.get r2 && L.contains l 1 && L.contains l 2)))

(* Test 3: two concurrent removes of the same element.
   Exactly one remove succeeds and the element is gone afterwards. *)
let two_removes_same_element () =
  Atomic.trace (fun () ->
    let l = L.create () in
    ignore (L.add l 42);
    let r1 = Atomic.make false in
    let r2 = Atomic.make false in
    Atomic.spawn (fun () -> Atomic.set r1 (L.remove l 42));
    Atomic.spawn (fun () -> Atomic.set r2 (L.remove l 42));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        let a = Atomic.get r1 and b = Atomic.get r2 in
        a <> b && not (L.contains l 42))))

(* Test 4: add and remove racing on the same element, starting empty.
   Two valid linearizations:
     remove first -> remove = false, add = true, element present
     add first    -> add = true, remove = true, element absent
   add = false is always a bug: nothing else adds 42. *)
let add_remove_race () =
  Atomic.trace (fun () ->
    let l = L.create () in
    let r_add = Atomic.make false in
    let r_rem = Atomic.make false in
    Atomic.spawn (fun () -> Atomic.set r_add (L.add l 42));
    Atomic.spawn (fun () -> Atomic.set r_rem (L.remove l 42));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        match Atomic.get r_add, Atomic.get r_rem with
        | true, false -> L.contains l 42
        | true, true -> not (L.contains l 42)
        | false, _ -> false)))

(* Test 5: conservation — elements are neither created nor lost.
   Four threads: add 1, add 2, remove 1, remove 2.  Both adds succeed
   (each element is added once to an initially empty list), and each
   element is present afterwards iff its remove failed, i.e. the remove
   ran before the add. *)
let conservation () =
  Atomic.trace (fun () ->
    let l = L.create () in
    let ra1 = Atomic.make false in
    let ra2 = Atomic.make false in
    let rr1 = Atomic.make false in
    let rr2 = Atomic.make false in
    Atomic.spawn (fun () -> Atomic.set ra1 (L.add l 1));
    Atomic.spawn (fun () -> Atomic.set ra2 (L.add l 2));
    Atomic.spawn (fun () -> Atomic.set rr1 (L.remove l 1));
    Atomic.spawn (fun () -> Atomic.set rr2 (L.remove l 2));
    Atomic.final (fun () ->
      Atomic.check (fun () ->
        Atomic.get ra1 && Atomic.get ra2
        && L.contains l 1 = not (Atomic.get rr1)
        && L.contains l 2 = not (Atomic.get rr2))))

(* Negative test: the same list built on a CAS that is NOT atomic (a read
   followed by a separate write).  Two adds can then both "succeed" on the
   same window and one node is lost.  DSCheck must find that interleaving;
   if it does not, the tests above are not exploring the list's internals. *)
module Racy_cas = struct
  include Atomic

  let compare_and_set r seen v =
    if get r == seen then (set r v; true) else false
end

let expect_violation name test =
  match test () with
  | () -> failwith (name ^ ": DSCheck found no violation in a buggy list")
  | exception Assert_failure _ ->
    print_endline (name ^ ": violation found, as expected")

let () =
  two_adds_same_element (module L) ();
  print_endline "Two adds of the same element test passed!";
  two_adds_distinct_elements (module L) ();
  print_endline "Two adds of distinct elements test passed!";
  two_removes_same_element ();
  print_endline "Two removes of the same element test passed!";
  add_remove_race ();
  print_endline "Add/remove race test passed!";
  conservation ();
  print_endline "Conservation test passed!";
  (* Run last: DSCheck's global state is not reset after a failed check. *)
  expect_violation "Racy CAS, two distinct adds"
    (two_adds_distinct_elements (module Lockfree_list.Make (Racy_cas)));
  print_endline "All dscheck_lockfree_list tests passed!"
