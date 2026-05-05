# Lecture 11: OxCaml

OxCaml's mode system as a compile-time alternative to the runtime
discipline used throughout the rest of the course (locks, atomics,
careful ownership). The handout walks through locality, contention,
portability, uniqueness, linearity, fork-join parallelism, capsules,
and zero-allocation programming, with course back-references at every
step.

## Files

- `11_oxcaml.key` — Keynote slide deck.
- `handout.md` — main lecture handout. Every `# `-prefixed OCaml block
  is exercised by `ocaml-mdx test` under the `5.2.0+ox` switch; if the
  toplevel's output drifts from what the handout expects, the test
  fails with a diff.
- `test_handout.sh` — runs `ocaml-mdx test` against `handout.md` and
  exits non-zero on any diff. Generates a one-off shim that adds
  `-extension-universe alpha` to `ocaml`.
- `code/` — standalone, compilable examples (one directory per topic,
  numbered `01_…` through `10_…`). Build with `dune build --root code/`.

## Building

Requires the `5.2.0+ox` opam switch (see the handout's Setup section).

```sh
eval $(opam env --switch=5.2.0+ox --set-switch)
./test_handout.sh             # verify handout
dune build --root code/       # build all standalone examples
