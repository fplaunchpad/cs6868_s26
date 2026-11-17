# CS6868: Concurrent Programming (IITM Spring 2026)

This is the GitHub repo for the course CS6868 Concurrent Programming taught at
IITM in the Spring semester 2026. The course website is here:
https://kcsrk.info/cs6868_s26/.

## Course Overview

This course teaches the fundamentals of concurrent and parallel programming,
with a focus on shared-memory multiprocessor systems. Topics include:

- Principles of concurrent programming
- Mutual exclusion and synchronization
- Concurrent data structures
- Lock-free and wait-free algorithms
- Memory models and consistency
- Parallel programming patterns
- Effect handlers
- Nested parallelism, Asynchronous I/O
- Practical implementations using OCaml 5's multicore features
- Safe parallel programming with OxCaml

The course uses OCaml 5 with its native support for parallelism via
[domains](https://ocaml.org/manual/5.4/api/Domain.html) and concurrency via
[effect handlers](https://ocaml.org/manual/5.4/api/Effect.html).

## Repository Structure

- `lectures/` - Lecture materials and code examples
- `assignments.md` - Course assignments
- `schedule.md` - Course schedule
- `resources.md` - Additional learning resources

## Prerequisites

OCaml parts of CS3100 or equivalent experience with functional programming
and basic understanding of operating systems and computer architecture.

## Getting Started

```bash
git clone https://github.com/kayceesrk/cs6868_s26
cd cs6868_s26
```

### Software Setup

We will use OCaml 5.4 or later. Follow the instructions at
https://ocaml.org/docs/install.html to install OCaml and the platform tools. Use
Linux, macOS, *BSD or WSL on Windows for best compatibility. Some of the later
lectures will need Linux tools. At IITM, you can use the DCF machines, which
have the tools installed.

Below is the instruction for Linux/macOS systems.

```bash
bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"
opam init # initialize opam
opam switch create 5.4.0 # create a new switch with OCaml 5.4.0
opam install ocaml-lsp-server.1.24.0 ocamlformat.0.28.1 utop.2.16.0 qcheck-lin.0.10 qcheck-stm.0.10 dscheck.0.5.0 # install course packages
```

It is recommended that you use VSCode with the [OCaml
Platform](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform)
extension for development.

Refer to individual lecture directories for specific setup instructions.

## Acknowledgements

The course material is inspired by and adapted from various sources, including:

- [The Art of Multiprocessor Programming, 2nd Edition](https://shop.elsevier.com/books/the-art-of-multiprocessor-programming/herlihy/978-0-12-415950-1) by Maurice Herlihy, Nir Shavit, Victor Luchangco, and Michael Spear
- [YSC4231: Parallel, Concurrent and Distributed Programming](https://ilyasergey.net/YSC4231/), taught by Ilya Sergey at Yale NUS College.
- [Control structures in programming languages: from goto to algebraic effects](https://xavierleroy.org/control-structures/), Xavier Leroy.
