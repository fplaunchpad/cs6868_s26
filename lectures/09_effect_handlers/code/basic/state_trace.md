# State-passing style — Execution trace

## Handler

```ocaml
| x               -> fun s -> (s, x)
| effect Get, k   -> fun s -> (continue k s) s
| effect Set v, k -> fun s -> (continue k ()) v
```

---

## Trace 1

Expression: `IS.run 0 (fun () -> ())`

`comp` returns `()` immediately — no effects.

Matches: `| x -> fun s -> (s, x)` where `x = ()`

```
  (fun s -> (s, ())) 0
= (0, ())
```

---

## Trace 2

Expression: `IS.run 0 (fun () -> get ())`

`comp` performs `Get`.

```
k = fun v -> v
```

Matches: `| effect Get, k -> fun s -> (continue k s) s`

```
  (fun s -> (continue k s) s) 0
= (continue k 0) 0
= (fun s -> (s, 0)) 0          (* k returns 0, matches: | x -> ... *)
= (0, 0)
```

---

## Trace 3

Expression: `IS.run 0 (fun () -> set 42)`

`comp` performs `Set 42`.

```
k = fun v -> v
```

Matches: `| effect (Set 42), k -> fun s -> (continue k ()) 42`

```
  (fun s -> (continue k ()) 42) 0
= (continue k ()) 42
= (fun s -> (s, ())) 42        (* k returns (), matches: | x -> ... *)
= (42, ())
```

---

## Trace 4

Expression:

```ocaml
IS.run 0 (fun () ->
  let x = get () in
  set (x + 1);
  get ())
```

### Step 1: performs `Get`

```
k = fun v ->
  let x = v in
  set (x + 1);
  get ()
```

Matches: `| effect Get, k -> fun s -> (continue k s) s`

```
  (fun s -> (continue k s) s) 0
= (continue k 0) 0
```

Resumes as: `let x = 0 in set (x + 1); get ()`

### Step 2: performs `Set 1`

```
k = fun () -> get ()
```

Matches: `| effect (Set 1), k -> fun s -> (continue k ()) 1`

```
  (fun s -> (continue k ()) 1) 0
= (continue k ()) 1
```

Resumes as: `get ()`

### Step 3: performs `Get`

```
k = fun v -> v
```

Matches: `| effect Get, k -> fun s -> (continue k s) s`

```
  (fun s -> (continue k s) s) 1
= (continue k 1) 1
```

Resumes, returns `1`.

### Step 4: returns `1`

Matches: `| x -> fun s -> (s, x)`

```
  (fun s -> (s, 1)) 1
= (1, 1)
```
