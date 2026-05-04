# Lecture 11: OxCaml — From Runtime Discipline to Compile-Time Safety

Throughout this course, we've built concurrent programs by following
**runtime conventions**: always acquire the lock before accessing shared
state, use atomics for simple counters, don't forget to release the lock
on the error path. The compiler doesn't help — if you forget a lock,
you get a data race that may only surface under load in production.

OxCaml (Jane Street's extended OCaml compiler) takes a different approach.
It extends OCaml's type system with **modes** — annotations that describe
*how* a value can be used, not *what* it is. The compiler then statically
rejects programs that would create data races, just as OCaml's type system
rejects programs that would add an integer to a string.

OxCaml is a strict superset of OCaml: every OCaml program is a valid
OxCaml program. The extensions are opt-in.

This lecture revisits problems we've already encountered and shows how
OxCaml's type system turns runtime conventions into compile-time guarantees:

- **Lecture 02 (Mutual Exclusion)** → **contention** mode. We protected
  shared state with `Mutex.lock`/`Mutex.unlock`; forget the lock and you
  get a race the compiler can't see. The contention mode (`uncontended`
  / `contended`) prevents this statically.
- **Lecture 04 (Memory Consistency)** → **contention** mode + mode
  crossing. Atomics let us share simple values safely. OxCaml's
  `Atomic.t` mode-crosses contention — its whole purpose is to be
  shared across domains, and the type system enforces it.
- **Lecture 05 (Spinlocks)** → **portability** + **contention**. We used
  TSAN to *detect* races dynamically. The two modes together make race
  freedom a type-checking job — no test run required.
- **Lecture 06 (Monitors)** → **contention** + a brand-based `access`
  token. A monitor bundles data with its lock by convention. Capsules
  make the bundling structural — the access token is required to read
  the data, and is only granted inside the critical section.
- **Lectures 07–08 (Linked Lists, Queues)** → **uniqueness** +
  **linearity** modes. Hand-over-hand locking and lock-free protocols
  rely on careful reasoning about who owns what. `unique` tracks past
  aliasing; `once` tracks future use — together they let the compiler
  enforce ownership disciplines that were previously programmer
  conventions.
- **Lectures 09–10 (Effect Handlers, Lightweight Concurrency)** →
  **locality** mode. Fiber schedulers heap-allocate state on every
  switch. `local` / `stack_` / `exclave_` (plus `let mutable` and
  unboxed types) put that state on the stack instead.

### Motivating Example: The Gensym Race

Consider a symbol generator we might use for naming AST nodes:

```ocaml
# let gensym =
    let count = ref 0 in
    fun prefix ->
      count := !count + 1;
      prefix ^ "_" ^ string_of_int !count;;
val gensym : string -> string = <fun>
```

Used sequentially, this is fine. Called from two domains in parallel,
ingredient-by-ingredient it satisfies all four conditions for a data race
from Lecture 02:

1. two domains, ✅
2. shared `count`, ✅
3. both write, ✅
4. `count` is a plain `ref`, not atomic, ✅

In Lecture 05 we'd run TSAN and watch it report the race. OxCaml does
better: it refuses the program at compile time. Try to spawn `gensym`
on another domain and the type checker stops you cold:

```ocaml
# let _ = Domain.Safe.spawn (fun () -> gensym "x");;
Line 1, characters 38-44:
Error: The value gensym is nonportable but is expected to be portable
       because it is used inside the function at Line 1, characters 27-49
       which is expected to be portable.
```

`Domain.Safe.spawn` requires a **portable** closure — one that's safe
to run on another domain. Our `gensym` captures a mutable `ref` and is
therefore `nonportable`. No test run, no race detector, no production
incident — the compiler rejects the spawn before any thread is even
created.

Our standard runtime fix is `Atomic.fetch_and_add`:

```ocaml
# let gensym_atomic =
    let count = Atomic.make 0 in
    fun prefix ->
      let n = Atomic.fetch_and_add count 1 in
      prefix ^ "_" ^ string_of_int n;;
val gensym_atomic : string -> string = <fun>
```

`Atomic.t` mode-crosses contention, so `gensym_atomic` *is* portable
and `Domain.Safe.spawn` accepts it.

This works because the operation fits in one atomic word. But what about
the data structures from Lectures 07–08 — linked lists, hash tables,
queues? Atomics aren't enough; we wrap them in a mutex and **hope nobody
forgets to lock**. That hope is the entire failure mode of concurrent
programming. OxCaml's plan is simple: **make forgetting impossible at the
type level**.

> **Hands-on**: three activities in the
> [OxCaml ICFP 2025 tutorial](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity)
> walk through this progression — `act01_data_races_and_tsan`,
> `act02_gensym_atomics`, `act03_gensym_capsules`. We'll meet the capsules
> version in Part 5.

### Setup

<!-- $MDX skip -->
```bash
opam update
opam switch create 5.2.0+ox --repos ox=git+https://github.com/oxcaml/opam-repository.git,default
eval $(opam env --switch 5.2.0+ox)
```

Packages: `parallel`, `parallel.scheduler`, `capsule`, `await`,
`await.blocking`, `await.capsule`, `base`, `stdio`

Code examples: `lectures/11_oxcaml/code/`

## Part 1: Safe Stack Allocation

We'll thread a single running example through this section: computing
the **path length of a polyline** — a sequence of waypoints in the
plane, like a GPS track or a graphics primitive. Naively, every
`point` we construct, every difference vector we compute, every
intermediate sum lives on the heap and waits for the GC. With OxCaml
we'll push every one of those allocations onto the stack and check at
compile time that none of them escape.

### The Problem: GC Pressure in Hot Paths

Suppose we want to compute the length of a path through a sequence of
points. The natural OCaml code allocates a `point` for each waypoint,
takes vector differences (more allocations), and sums up Euclidean
distances. Every inner step touches the heap. In a hot loop — say, a
graphics renderer or a physics simulator — this allocation traffic
becomes the bottleneck. The garbage collector ends up doing more work
than the algorithm.

What if those temporaries could live on the **stack**, freed
automatically when the function returns? The compiler needs to know
one thing: **does this value escape its scope?** If not, it can safely
live on the stack.

### Locality: `local` vs `global`

OxCaml introduces a **locality** mode. Every value is either `local`
(does not escape its scope) or `global` (may live indefinitely on the
heap). The `@ local` annotation on a parameter is a promise from the
caller that the value won't be captured or returned. Here's the
smallest possible example, before we get to points:

```ocaml
# let use_locally (x @ local) = x + 1;;
val use_locally : int @ local -> int = <fun>
# use_locally 42;;
- : int = 43
```

The return type is `int` (global by default) — the function takes a
local value and produces a global result. This is fine because `int` is
immediate and doesn't require heap allocation. We'll come back to that
when we discuss **mode crossing**.

### Stack Allocation with `stack_`

The `stack_` keyword forces an allocation onto the stack. Let's set up
the running example: a 2-D point, and the Euclidean distance between
two points.

```ocaml
# type point = { x : float; y : float };;
type point = { x : float; y : float; }
```

```ocaml
# let distance (a @ local) (b @ local) =
    let dx = a.x -. b.x in
    let dy = a.y -. b.y in
    Float.sqrt (dx *. dx +. dy *. dy);;
val distance : point @ local -> point @ local -> float = <fun>
```

`distance` accepts its arguments at mode `local` — promising not to
capture or return them — and returns a `float`. The two parameters can
therefore live on the stack:

```ocaml
# let test_distance () =
    let a = stack_ { x = 0.0; y = 0.0 } in
    let b = stack_ { x = 3.0; y = 4.0 } in
    let d = distance a b in
    d;;
val test_distance : unit -> float = <fun>
# test_distance ();;
- : float = 5.
```

Both points live on `test_distance`'s stack frame. When it returns,
they're gone — no GC involved.

### What Happens When a Local Value Escapes?

The compiler catches escape attempts at compile time. Suppose we made
a mistake and tried to return one of our stack-allocated points:

```ocaml
# let escape_demo () =
    let p = stack_ { x = 1.0; y = 2.0 } in
    p;;
Line 3, characters 5-6:
Error: This value is local
       because it is stack_-allocated.
       However, the highlighted expression is expected to be local to the parent region or global
       because it is a function return value.
       Hint: Use exclave_ to return a local value.
```

Or tried to stash one in a global mutable cell:

```ocaml
# let store_local () =
    let p = stack_ { x = 1.0; y = 2.0 } in
    let r = ref p in
    !r;;
Line 3, characters 17-18:
Error: This value is local
       because it is stack_-allocated.
       However, the highlighted expression is expected to be global.
```

Think of it this way: `stack_` allocates in the current function's
**region**. When the function returns, the region is destroyed. Any
reference to that memory would be a dangling pointer — so the compiler
forbids it. The error message even tells us the fix.

### Returning Local Values with `exclave_`

We often want a helper function that *returns* a freshly-built point.
Where should that point be allocated? Not in the helper's own region —
that's about to disappear when the helper returns. Instead, we want
the allocation to happen in the **caller's** region. That's what
`exclave_` does:

```ocaml
# let midpoint (a @ local) (b @ local) : point @ local =
    exclave_ { x = (a.x +. b.x) /. 2.0; y = (a.y +. b.y) /. 2.0 };;
val midpoint : point @ local -> point @ local -> point @ local = <fun>
```

The return type `point @ local` says the caller gets a local value;
the `exclave_` keyword says "allocate this in the caller's region, not
mine." Helpers compose — `exclave_` lets us build longer chains of
local returns:

```ocaml
# let translate (p @ local) (dx : float) (dy : float) : point @ local =
    exclave_ { x = p.x +. dx; y = p.y +. dy };;
val translate : point @ local -> float -> float -> point @ local = <fun>
```

`stack_` only works on syntactic allocation sites (tuples, records,
closures, boxed numbers). You can't write `stack_ (midpoint a b)` —
`midpoint a b` is a function call, not an allocation. The function
itself uses `exclave_` to do the work.

### Mode Crossing

Look back at `distance`. It takes two `local` points and returns a
`float`. The result escapes the function freely — no `exclave_`
needed. Why? Because `float` (like `int` and `bool`) is immediate: the
value lives in a register, not on the heap. Locality is irrelevant for
something that doesn't allocate.

This is called **mode crossing**: types that don't involve heap
allocation cross the locality axis freely. We rely on this for the
running example — `distance` is a "local in, global out" function,
which is exactly what we need to compute a path length and return the
answer to global code.

We can build up a multi-segment computation with the same property:

```ocaml
# let triangle_perimeter (a @ local) (b @ local) (c @ local) : float =
    distance a b +. distance b c +. distance c a;;
val triangle_perimeter :
  point @ local -> point @ local -> point @ local -> float = <fun>
# let test_perimeter () =
    let a = stack_ { x = 0.0; y = 0.0 } in
    let b = stack_ { x = 3.0; y = 0.0 } in
    let c = stack_ { x = 3.0; y = 4.0 } in
    let p = triangle_perimeter a b c in
    p;;
val test_perimeter : unit -> float = <fun>
# test_perimeter ();;
- : float = 12.
```

Three stack-allocated points, three calls to `distance`, no heap
allocation, and the `float` answer escapes to global scope.

### Working with Local Lists

A polyline of arbitrary length is naturally a `point list`. The
`@ local` annotation extends through structures: a `point list @ local`
is a list whose cons cells *and* whose points all live in the current
region. We can compute path length of an arbitrary polyline with no
heap traffic at all:

```ocaml
# let rec path_length (poly : point list @ local) : float =
    match poly with
    | a :: (b :: _ as rest) -> distance a b +. path_length rest
    | _ -> 0.0;;
val path_length : point list @ local -> float = <fun>
```

The traversal allocates nothing — `rest` is just a local pointer into
the existing list, and `distance` returns a mode-crossing `float`.

For operations that *build* a new local list — say, translating every
point of a polyline by some offset — every cons must be allocated in
the **caller's** region, so we wrap the result in `exclave_`:

```ocaml
# let rec translate_polyline (poly : point list @ local) dx dy
    : point list @ local =
    match poly with
    | [] -> exclave_ []
    | p :: rest ->
        exclave_ (translate p dx dy :: translate_polyline rest dx dy);;
val translate_polyline :
  point list @ local -> float -> float -> point list @ local = <fun>
```

Notice the recursion sits *inside* the `exclave_`: each cons cell —
including the one built from the recursive result — is allocated in
the caller's region. This is exactly the shape of the zero-allocation
merge sort we'll see in Part 6.

> **Hands-on**:
> [`act04_local_lists`](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity/act04_local_lists)
> walks through generic `iter` and `map` on local lists.

## Part 2: Modes and Data-Race Freedom

### Recall: The Four Ingredients of a Data Race

From Lecture 02, a data race requires all four of these simultaneously:

1. **Two domains** executing code in parallel
2. **A shared memory location** accessible by both
3. **At least one write** — read-read is fine
4. **The location is not atomic** — atomics have special semantics

Remove any one ingredient and the race disappears. Standard OCaml 5 gives
you domains but no compile-time help with ingredients 2–4. You rely on
runtime discipline: "don't forget the lock."

OxCaml's mode system attacks ingredients 2 and 3 at compile time through
two new modal axes: **contention** and **portability**. Together they
give the compiler enough information to reject the unsafe parallel
`gensym` we wrote in the introduction.

### What Are Modes?

Modes describe *how* a value can be used. They are orthogonal to types.
A value of type `thing` might be:
- `thing @ uncontended` — only one domain can access it
- `thing @ contended` — it might be accessed by multiple domains
- `thing @ shared` — multiple domains can read it simultaneously

The key insight: **the same type can appear at different modes in different
contexts**. A `thing` starts as `uncontended` when it's local to one
domain, but becomes `contended` when it's captured in a parallel closure.

### The Contention Axis: `uncontended` vs `contended`

The contention mode tracks whether a value might be simultaneously
accessed by multiple domains.

**Rule 1**: If a value is `contended`, you cannot read or write its
mutable fields.

Let's see this in action:

```ocaml
# type mood = Happy | Neutral | Sad;;
type mood = Happy | Neutral | Sad
# type thing = { price : float; mutable mood : mood };;
type thing = { price : float; mutable mood : mood; }
```

Reading an immutable field is fine even when contended:

```ocaml
# let price_contended (t @ contended) = t.price;;
val price_contended : thing @ contended -> float = <fun>
```

But writing a mutable field is not:

```ocaml
# let cheer_up_contended (t @ contended) = t.mood <- Happy;;
Line 1, characters 42-43:
Error: This value is contended but is expected to be uncontended
       because its mutable field mood is being written.
```

Even *reading* a mutable field from a contended value is rejected — because
another domain might be writing to it at the same time:

```ocaml
# let read_mood_contended (t @ contended) = t.mood;;
Line 1, characters 43-44:
Error: This value is contended but is expected to be shared or uncontended
       because its mutable field mood is being read.
```

This connects directly to our data race ingredients: ingredient 3 says
at least one access must be a write. But the compiler can't know at the
read site whether some other domain is writing — so it conservatively
rejects both reads and writes on contended mutable fields.

Without the `@ contended` annotation, values default to `uncontended`,
and everything works as in regular OCaml:

```ocaml
# let cheer_up t = t.mood <- Happy;;
val cheer_up : thing -> unit = <fun>
# let read_mood t = t.mood;;
val read_mood : thing -> mood = <fun>
```

**Rule 2**: Everything inside a `contended` value is also `contended`.
You can't extract an `uncontended` component from a `contended` container.

### The Portability Axis: `portable` vs `nonportable`

Portability tracks whether a value can safely **cross domain boundaries**.
This attacks ingredient 1 of data races: if a value can't reach another
domain, it can't participate in a race.

A `portable` function is one that can be safely called from any domain.
The critical constraint: **inside a `portable` function, all captured
values from the outer scope are treated as `contended`**. This is because
if the function runs on another domain, the captured values might be
simultaneously accessed by the original domain.

Let's see this concretely:

```ocaml
# let test_portable () =
    let (f @ portable) = fun x y -> x + y in
    f 1 2;;
val test_portable : unit -> int = <fun>
# test_portable ();;
- : int = 3
```

A pure function (no mutable captures) is portable. But a function that
captures a mutable ref is not:

```ocaml
# let test_nonportable () =
    let r = ref 0 in
    let counter () = incr r; !r in
    let (f @ portable) = counter in
    f ();;
Line 4, characters 26-33:
Error: This value is nonportable
       because it contains a usage (of the value r at Line 3, characters 27-28)
       which is expected to be uncontended.
       However, the highlighted expression is expected to be portable.
```

Read the error message carefully: the compiler tells you *exactly why*
`counter` is nonportable — it captures `r`, which must be `uncontended`,
but portable functions treat captured values as `contended`.

### Connecting the Axes: Why Both Are Needed

Consider this scenario from earlier in the course:

```
Domain 1                    Domain 2
────────                    ────────
t.mood <- Happy             t.mood <- Sad      ← DATA RACE!
```

The mode system prevents this with a two-step argument:

1. **Portability** ensures that closures passed to `fork_join2` are
   `portable`, meaning they treat captured values as `contended`
2. **Contention** ensures that `contended` values can't have their
   mutable fields read or written

Together, these two rules make data-race freedom a compile-time guarantee.

### Captured Values vs Parameters

An important subtlety: portability restricts *captured* outer values, not
parameters. Parameters are "inside" the function and can be used at their
declared mode:

```ocaml
# let factorial_portable n =
    let a = ref 1 in
    let rec (loop @ portable) (a @ uncontended) i =
      if i > 0 then begin
        a := !a * i;
        loop a (i - 1)
      end
    in
    loop a n;
    !a;;
val factorial_portable : int -> int = <fun>
# factorial_portable 10;;
- : int = 3628800
```

Here `loop` is `portable` — it doesn't capture `a` from the outer scope.
Instead, `a` is passed as a parameter annotated `@ uncontended`. The
function can safely mutate `a` because it received it as a parameter, not
by capturing it.

This distinction is crucial for understanding `fork_join2`: the closures
you pass are `portable`, but the `par` parameter they receive is not
captured — it's passed in fresh.

## Part 3: Uniqueness and Linearity

The mode system has two more axes that address a different class of bugs:
**use-after-free** and **double-free**. These are the kinds of errors that
plague C/C++ programs and that Rust's ownership system prevents. OxCaml
provides similar guarantees through the **uniqueness** and **linearity**
modes.

| Axis | Restrictive | Permissive | Tracks |
|------|-------------|------------|--------|
| Uniqueness | `unique` | `aliased` | Has this value been aliased in the **past**? |
| Linearity | `once` | `many` | Can this value be used multiple times in the **future**? |

### Uniqueness: Tracking Aliasing

A value annotated `@ unique` is guaranteed to have no other references.
This enables safe resource management — if you know a value isn't aliased,
you can safely free it, move it, or destructively update it.

Consider an explicitly memory-managed reference. The unsafe version allows
use-after-free:

```ocaml skip
(* Unsafe — no compile-time protection *)
module type Unsafe_ref = sig
  type 'a t
  val alloc : 'a -> 'a t
  val free : 'a t -> unit      (* nothing stops use-after-free *)
  val get : 'a t -> 'a
  val set : 'a t -> 'a -> unit
end
```

With uniqueness, we can make the interface safe:

```ocaml
# module type Unique_ref = sig
    type 'a t
    val alloc : 'a -> 'a t @ unique
    val free : 'a t @ unique -> unit
    val get : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique
    val set : 'a t @ unique -> 'a -> 'a t @ unique
  end;;
module type Unique_ref =
  sig
    type 'a t
    val alloc : 'a -> 'a t @ unique
    val free : 'a t @ unique -> unit
    val get : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique
    val set : 'a t @ unique -> 'a -> 'a t @ unique
  end
```

The key design: every operation consumes the unique reference and returns
a new one (or, in the case of `free`, returns nothing). This creates a
**linear chain of ownership** — after `free`, there's no reference left
to use.

The `Modes.Aliased.t` wrapper on the return of `get` lets the retrieved
value be aliased (you might want multiple copies of the stored data),
while the reference itself stays unique.

Here's an implementation:

```ocaml
# module M : Unique_ref = struct
    type 'a t = { mutable value : 'a }
    let alloc x = { value = x }
    let free _t = ()
    let get t =
      let a = Modes.Aliased.{ aliased = t.value } in
      a, t
    let set t x =
      t.value <- x;
      t
  end;;
module M : Unique_ref
```

Correct usage follows the ownership chain:

```ocaml
# open M;;
```

```ocaml
# let okay r =
    let _v, r = get r in
    let r = set r 20 in
    free r;;
val okay : int t @ unique -> unit = <fun>
```

But use-after-free is a **compile-time error**:

```ocaml
# let use_after_free r =
    free r;
    get r;;
Line 3, characters 9-10:
Error: This value is used here, but it has already been used as unique:
Line 2, characters 10-11:

```

And double-free is caught too:

```ocaml
# let double_free r =
    free r;
    free r;;
Line 3, characters 10-11:
Error: This value is used here, but it has already been used as unique:
Line 2, characters 10-11:

```

The compiler tracks that `r` was consumed by the first `free` and rejects
the second use. No runtime checks needed — this is purely static.

### Linearity: Controlling Future Use

Uniqueness tracks the **past** — has a value been aliased? Linearity
tracks the **future** — how many times can a value be used?

A `once` value can be used at most once. A `many` value (the default)
can be used any number of times.

Why do we need both? Consider capturing a unique value in a closure:

```ocaml
# let capture_problem () =
    let t = M.alloc 42 in
    let f () = M.free t in
    f ();
    f ();;
Line 5, characters 5-6:
Error: This value is used here,
       but it is defined as once and has already been used:
Line 4, characters 5-6:

```

What happened? The closure `f` captures `t @ unique`. Since `t` is unique,
the closure can only be called once — otherwise `free` would be called
twice on the same resource. The compiler automatically gives `f` the mode
`once`, and rejects the second call.

This is the interplay between uniqueness and linearity: **capturing a
unique value in a closure makes the closure `once`**.

### A `once` Function

You can explicitly create `once` functions:

```ocaml
# let make_once_fn () : (unit -> int) @ once =
    let v @ unique = 42 in
    fun () -> v;;
val make_once_fn : unit -> (unit -> int) @ once = <fun>
```

Using it once is fine:

```ocaml
# let use_once () =
    let f = make_once_fn () in
    let result = f () in
    Printf.printf "%d\n" result;;
val use_once : unit -> unit = <fun>
# use_once ();;
42
- : unit = ()
```

Using it twice is rejected:

```ocaml
# let use_twice () =
    let f = make_once_fn () in
    let _ = f () in
    f ();;
Line 4, characters 5-6:
Error: This value is used here,
       but it is defined as once and has already been used:
Line 3, characters 13-14:

```

### Linear References

We can also build a safe reference using linearity instead of uniqueness:

```ocaml
# module type Linear_ref = sig
    type 'a t
    val alloc : 'a -> 'a t @ once
    val free : 'a t @ once -> unit
    val get : 'a t @ once -> 'a * 'a t @ once
    val set : 'a t @ once -> 'a -> 'a t @ once
  end;;
module type Linear_ref =
  sig
    type 'a t
    val alloc : 'a -> 'a t @ once
    val free : 'a t @ once -> unit
    val get : 'a t @ once -> 'a * 'a t @ once
    val set : 'a t @ once -> 'a -> 'a t @ once
  end
```

```ocaml
# module LR : Linear_ref = struct
    type 'a t = { mutable value : 'a }
    let alloc x = { value = x }
    let free _t = ()
    let get t = t.value, t
    let set t x = t.value <- x; t
  end;;
module LR : Linear_ref
```

Usage follows the same ownership-chain pattern:

```ocaml
# open LR;;
```

```ocaml
# let linear_works () =
    let r = alloc 42 in
    let v, r = get r in
    let r = set r (v + 1) in
    let v, r = get r in
    Printf.printf "%d\n" v;
    free r;;
val linear_works : unit -> unit = <fun>
# linear_works ();;
43
- : unit = ()
```

And use-after-free is caught:

```ocaml
# let linear_fails () =
    let r = alloc 42 in
    free r;
    get r;;
Line 4, characters 9-10:
Error: This value is used here,
       but it is defined as once and has already been used:
Line 3, characters 10-11:

```

### Uniqueness vs Linearity: Why Both?

Both prevent use-after-free, but they reason differently:

- **Uniqueness** (`free : 'a t @ unique -> unit`): The signature alone
  tells you `free` is safe — if `t` is unique, there are no other
  references, so deallocation can't create dangling pointers. **Modular
  reasoning.**

- **Linearity** (`free : 'a t @ once -> unit`): You know `free` is
  called at most once, but safety depends on the whole API ensuring
  the value isn't used afterward. **Whole-API reasoning.**

The difference shows up in how they handle time:

- **Uniqueness looks at the past**: "has this value been aliased?" A
  unique value may become aliased in the future (by passing it somewhere
  that doesn't require uniqueness).

- **Linearity looks at the future**: "will this value be used again?"
  Any value can be restricted to `once`, regardless of past aliasing.

Submoding works as expected — `many` values can be passed where `once`
is expected (using something fewer times is always fine), and `unique`
values can be passed where `aliased` is expected (having no aliases is
a stronger guarantee):

```ocaml
# let once_to_many () =
    let set_to_20 (r @ once) =
      r := 20
    in
    let r @ many = ref 10 in
    set_to_20 r;;
val once_to_many : unit -> unit = <fun>
```

### The Full Mode Picture

Here are all the modal axes together:

| Axis | Restrictive | Permissive | Controls |
|------|-------------|------------|----------|
| Locality | `local` | `global` | Can the value escape its scope? |
| Portability | `portable` | `nonportable` | Can it cross domain boundaries? |
| Contention | `uncontended` | `contended` | Is it accessed by multiple domains? |
| Uniqueness | `unique` | `aliased` | Has it been aliased? |
| Linearity | `once` | `many` | Can it be used multiple times? |

Each axis tracks a different aspect of *how* a value is used. The compiler
checks all axes simultaneously, giving you:
- Stack allocation safety (locality)
- Data-race freedom (portability + contention)
- Resource safety (uniqueness + linearity)

All without runtime overhead — these are purely compile-time checks.

## Part 4: Fork-Join Parallelism

### `Parallel.fork_join2`

This is the core primitive for parallelism in OxCaml. It runs two
functions in parallel and returns both results:

```ocaml skip
val fork_join2 :
  Parallel.t ->
  (Parallel.t -> 'a) @ portable once ->
  (Parallel.t -> 'b) @ portable once ->
  #('a * 'b)
```

The mode annotations in the signature tell the whole story:
- **`portable`**: closures can run on any domain — captured values become `contended`
- **`once`**: each closure is called exactly once — no aliasing of side effects
- **`Parallel.t`**: a scheduling capability, passed as a parameter (not captured)
- **`#('a * 'b)`**: results returned as an unboxed tuple (no heap allocation)

Here's a complete example:

```ocaml skip
let run_parallel ~f =
  let scheduler = Parallel_scheduler.create () in
  let result = Parallel_scheduler.parallel scheduler ~f in
  Parallel_scheduler.stop scheduler;
  result

let () =
  let result = run_parallel ~f:(fun par ->
    let #(a, b) = Parallel.fork_join2 par
      (fun _par -> 21)
      (fun _par -> 21)
    in
    Printf.printf "result: %d\n" (a + b))
  in
  result
```

### Why Shared Arrays Don't Work (And What To Use Instead)

Consider parallelizing a dot product. The natural approach captures
arrays in `fork_join2` closures:

```ocaml skip
(* This does NOT compile *)
let rec dot_par par (a : float array) (b : float array) lo hi =
  let mid = lo + (hi - lo) / 2 in
  let #(left, right) =
    Parallel.fork_join2 par
      (fun par -> dot_par par a b lo mid)
      (fun par -> dot_par par a b mid hi)
  in
  left +. right
```

The compiler rejects this:

```
Error: This value is "shared"
       because it is used inside [a fork_join2 closure]
       which is expected to be "shareable".
       However, the highlighted expression is expected to be "uncontended".
```

Why? The closures are `portable`, so captured values become `contended`.
`Array.get` requires `uncontended` (even for reads, because another
domain might be writing). The compiler correctly prevents the
potential data race, even though in this case both branches only read.

**Solution: use `Iarray.t` (immutable arrays).** Immutable values mode-cross
the contention axis — if nobody can write, reads are always safe:

```ocaml skip
open! Base

let rec dot_par par (a : float Iarray.t) (b : float Iarray.t) lo hi =
  if hi - lo <= 8192 then dot_seq a b lo hi
  else
    let mid = lo + (hi - lo) / 2 in
    let #(left, right) =
      Parallel.fork_join2 par
        (fun par -> dot_par par a b lo mid)
        (fun par -> dot_par par a b mid hi)
    in
    left +. right
```

This compiles and runs correctly. The `Iarray.t` values freely cross
contention boundaries because they're immutable.

### Mutable Parallel Sort: `Slice.fork_join2`

For algorithms that need in-place mutation across parallel branches —
quicksort, in-place merge — `Iarray.t` won't work; we need to actually
write the array. OxCaml provides `Parallel.Arrays.Array.Slice`, which
lets you split a mutable array into provably **disjoint** slices. Each
branch of `fork_join2` receives a slice it provably owns; the type
system prevents both branches from touching the same element.

```ocaml skip
module Par_array = Parallel.Arrays.Array
module Slice = Par_array.Slice

let swap slice ~i ~j =
  let temp = Slice.get slice i in
  Slice.set slice i (Slice.get slice j);
  Slice.set slice j temp

let partition slice =
  let length = Slice.length slice in
  let pivot = Slice.get slice (length - 1) in
  let store = ref 0 in
  for i = 0 to length - 2 do
    if Slice.get slice i <= pivot then begin
      swap slice ~i ~j:!store;
      incr store
    end
  done;
  swap slice ~i:!store ~j:(length - 1);
  !store

let rec quicksort par slice =
  if Slice.length slice > 1 then begin
    let pivot = partition slice in
    let #((), ()) =
      Slice.fork_join2 par ~pivot slice
        (fun par left  -> quicksort par left)
        (fun par right -> quicksort par right)
    in ()
  end
```

The `~pivot` argument declares the split point; the two closures receive
disjoint slices of the underlying array. The compiler refuses any access
to the original full slice while the branches are running.

> **Hands-on**:
> [`act04_quicksort`](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity/act04_quicksort).

### Iarray Comprehensions

OxCaml has comprehension syntax for both lists (`[ e for x = ... ]`) and
immutable arrays (`[: e for x = ... :]`). The latter is particularly
useful in parallel code, since `Iarray.t` mode-crosses contention:

```ocaml skip
# [: i * i for i = 1 to 5 :];;
- : int iarray = [:1; 4; 9; 16; 25:]
```

You can build the input arrays for `dot_par` above with:

```ocaml skip
let a : float Iarray.t = [: Float.of_int i for i = 0 to n - 1 :]
let b : float Iarray.t = [: Float.of_int (i * 2) for i = 0 to n - 1 :]
```

### Atomics in OxCaml

Atomics work as you already know them, but now with mode-aware types.
`Atomic.t` crosses the contention axis — its whole point is to be
safely shared:

```ocaml skip
let next_id = Atomic.make 0

let gensym prefix =
  let id = Atomic.fetch_and_add next_id 1 in
  Printf.sprintf "%s_%d" prefix id
```

This connects to data race ingredient 4: atomic locations are the
carve-out. The mode system makes this explicit in the types.

## Part 5: Capsules — Safe Shared Mutable State

### The Problem Atomics Don't Solve

Atomics handle simple values — counters, flags. But what about sharing a
hash table, a buffer, or any complex mutable structure across parallel
tasks? This is exactly the setting of Lectures 06–08: monitor objects,
linked lists, queues. The standard fix is a `Mutex.t`:

```ocaml skip
(* Standard OCaml — no compile-time safety *)
let mutex = Mutex.create ()
let shared_table = Hashtbl.create 16

let safe_insert k v =
  Mutex.lock mutex;
  Hashtbl.add shared_table k v;
  Mutex.unlock mutex

(* Nothing stops you from forgetting the lock: *)
let unsafe_insert k v =
  Hashtbl.add shared_table k v   (* DATA RACE — compiles fine! *)
```

The mutex is a runtime convention. If you forget it, the compiler won't
help. The monitor pattern from Lecture 06 was precisely an attempt to
make "always lock before access" *structural* — but it was still enforced
by programmer discipline, not by the compiler.

### Capsules: Compile-Time Lock Discipline

A **capsule** is a branded container for mutable state. The brand is a
type parameter that connects the data to its lock. You literally cannot
access the data without proving you hold the lock — at the type level.

Three components:

- `Capsule.Mutex.t` — a mutex carrying a brand
- `Capsule.Data.t` — the encapsulated data, sharing the same brand
- `access` token — proof you hold the lock; required to unwrap the data

Let's revisit `gensym` from the introduction. We refused to use atomics
this time — perhaps because the counter has more structure (e.g., a
record), or because we want to perform multi-step updates atomically.
A plain `ref` would race. With a capsule, the compiler enforces the lock
discipline:

```ocaml skip
open Await

let gensym =
  let (P mutex) = Capsule.Mutex.create () in
  let counter = Capsule.Data.create (fun () -> ref 0) in
  let fetch_and_incr (w : Await.t) =
    Capsule.Mutex.with_lock w mutex ~f:(fun access ->
      let c = Capsule.Data.unwrap ~access counter in
      incr c;
      !c)
  in
  fun w prefix -> prefix ^ "_" ^ Int.to_string (fetch_and_incr w)
```

Read this carefully. The `counter` ref is created *inside* the capsule —
it has no name in scope outside `Capsule.Data.create`. To touch it, we
need to call `Capsule.Data.unwrap`, which **requires an `access` token**.
The only way to obtain `access` is through `Capsule.Mutex.with_lock`,
which only hands it out for the duration of the critical section. There
is no way to write the equivalent of "forgetting the lock" — the program
simply does not type-check.

We can now use `gensym` from parallel branches:

```ocaml skip
let gensym_pair par =
  let #(s1, s2) =
    Parallel.fork_join2 par
      (fun _ -> Await_blocking.with_await Terminator.never
                  ~f:(fun w -> gensym w "x"))
      (fun _ -> Await_blocking.with_await Terminator.never
                  ~f:(fun w -> gensym w "x"))
  in
  assert (s1 <> s2)
```

The critical difference from standard `Mutex.t`:

| Standard Mutex (Lec 02–06) | Capsule (OxCaml) |
|---|---|
| Lock and data are separate values | Data is *inside* the capsule |
| Forgetting to lock compiles fine | Forgetting to lock is a **type error** |
| Lock acquisition is a runtime call | Acquisition produces a typed `access` token |
| Runtime convention | Compile-time guarantee |

This is the monitor pattern from Lecture 06 — but the bundling of
"data + lock" is enforced by the type system, not by the programmer.

> **Hands-on**:
> [`act03_gensym_capsules`](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity/act03_gensym_capsules).

This makes the lock discipline *structural* rather than *conventional*.
You can't accidentally access the data without the lock, just as you
can't accidentally add an int to a string.

## Part 6: Performance Features

### `let mutable`

OxCaml adds `let mutable` — a mutable local binding that lives in a
register, avoiding `ref` allocation entirely:

```ocaml
# let sum_1_to_n n =
    let mutable acc = 0 in
    for i = 1 to n do
      acc <- acc + i
    done;
    acc;;
val sum_1_to_n : int -> int = <fun>
# sum_1_to_n 100;;
- : int = 5050
```

Compare: `let mutable acc = 0` uses no heap memory. The equivalent
`let acc = ref 0` allocates a mutable cell on the heap. In a tight loop,
this difference matters.

### Unboxed Tuples

Standard OCaml tuples are heap-allocated. OxCaml's unboxed tuples
`#(a, b)` are returned in registers:

```ocaml
# let swap #(x, y) = #(y, x);;
val swap : #('a * 'b) -> #('b * 'a) = <fun>
# swap #(1, 2);;
- : #(int * int) = #(2, 1)
```

This is what `fork_join2` returns — both results come back in registers,
not a heap-allocated pair. Zero allocation for the parallelism itself.

### `[@zero_alloc]`

The `[@zero_alloc]` attribute asks the compiler to statically verify that
a function performs no heap allocation:

```ocaml
# let[@zero_alloc][@inline never] fast_add x y = x + y;;
val fast_add : int -> int -> int [@@zero_alloc] = <fun>
```

At compile time with optimizations, the compiler checks and rejects
functions that allocate. This is critical for latency-sensitive code
where GC pauses are unacceptable — the same scenarios that motivated
careful pool-based allocation in our discussion of fiber schedulers
(Lecture 10).

### Putting It Together: Zero-Allocation Merge Sort

`let mutable`, local lists from Part 1, `exclave_`, and `[@zero_alloc]`
combine into a familiar algorithm with no heap traffic. Here is merge
sort over `int list @ local`, with the compiler statically verifying
that nothing escapes to the heap:

```ocaml skip
let[@zero_alloc] rec split (lst @ local) = exclave_
  match lst with
  | [] -> ([], [])
  | [_] -> (lst, [])
  | x :: y :: rest ->
      let (left, right) = split rest in
      (x :: left, y :: right)

let[@zero_alloc] rec merge
    (left : int list @ local) (right : int list @ local) = exclave_
  match left, right with
  | [], _ -> right
  | _, [] -> left
  | x :: xs, y :: ys ->
      if x <= y then x :: merge xs right
      else y :: merge left ys

let[@zero_alloc] rec merge_sort (lst @ local) = exclave_
  match lst with
  | [] | [_] -> lst
  | _ ->
      let (left, right) = split lst in
      merge (merge_sort left) (merge_sort right)
```

Every cons cell, every tuple, every recursive frame lives in the caller's
region. When the top-level call returns, all that storage is reclaimed
at once — no GC, no heap traffic. The `[@zero_alloc]` attribute makes
this a compile-time invariant, not a runtime hope.

Compare this to the conventional approach: writing a non-allocating
algorithm in OCaml means careful manual reasoning, then profiling to
verify, and the verification is invalidated by every refactor. Here it
is a *type*.

> **Hands-on**:
> [`act05_merge_sort`](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity/act05_merge_sort).
> A harder companion exercise is
> [`act05_radix_sort`](https://github.com/oxcaml/tutorial-icfp25/tree/main/handson_activity/act05_radix_sort).

## Summary

Mapping each problem to where we encountered it in the course, the
runtime fix we used, and OxCaml's compile-time alternative:

| Problem | Course lecture | Runtime approach | OxCaml |
|---|---|---|---|
| Escaping references | Lec 09–10 | Programmer discipline | `local` / `stack_` / `exclave_` |
| Data races | Lec 02 | "Always lock before access" | `contended` / `portable` modes |
| Race detection | Lec 05 (TSAN) | Dynamic, after-the-fact | Static, at compile time |
| Atomic counters | Lec 04–05 | `Atomic.t` (still works!) | Same `Atomic.t`, type-tracked |
| Lock + data bundling | Lec 06 (monitors) | Convention | Capsules |
| Use-after-free | Lec 07–08 | Discipline + runtime checks | `unique` mode |
| Double-free | Lec 07–08 | Discipline + runtime checks | `once` mode |
| Shared read access | Lec 03 | "Hope nobody writes" | `Iarray.t` mode-crosses contention |
| GC pressure in hot loops | Lec 09–10 | Accept it / pool manually | `let mutable`, unboxed, `[@zero_alloc]` |
| Structured parallelism | Lec 03 (`Domain.spawn`) | Manual thread management | `fork_join2` with mode-checked closures |

The fundamental shift: safety properties that were *conventions* become
*compiler-checked invariants*. The mode system doesn't add new runtime
mechanisms — it makes existing mechanisms (stack allocation, locks,
parallelism) verifiable at compile time.

A way to read this lecture in one sentence: **everything you've built by
hand over the last ten weeks, OxCaml lets you describe in types and let
the compiler check.**

## References

- [OxCaml ICFP 2025 Tutorial](https://github.com/oxcaml/tutorial-icfp25)
- [OxCaml Extensions Documentation](https://github.com/oxcaml/oxcaml/tree/main/jane/doc/extensions)
- [Jane Street Parallel Library](https://github.com/janestreet/parallel)
- [Zero-allocation webserver with OxCaml](https://anil.recoil.org/notes/oxcaml-httpz) — Anil Madhavapeddy
- [Uniqueness for Behavioural Types](https://kcsrk.info/ocaml/modes/oxcaml/2025/05/29/uniqueness_and_behavioural_types/) — KC Sivaramakrishnan
- [Linearity and Uniqueness](https://kcsrk.info/ocaml/modes/oxcaml/2025/06/04/linearity_and_uniqueness/) — KC Sivaramakrishnan
- [Linearity and Uniqueness: An Entente Cordiale](https://granule-project.github.io/papers/esop22-paper.pdf) — Marshall et al.
