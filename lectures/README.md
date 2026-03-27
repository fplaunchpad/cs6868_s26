---
layout: page
title: Lecture Summary
permalink: /lecture-summary/
---

## Lecture 01: Introduction

This lecture introduces the course on concurrent programming, covering the motivation for parallelism and concurrency on modern MIMD multiprocessor architectures. It distinguishes between shared-bus and distributed memory systems, and discusses key challenges such as memory contention, communication contention, and communication latency. The course language is OCaml 5, which supports both concurrency and parallelism. The lecture includes hands-on examples of parallel programming in OCaml using domains, including parallel Fibonacci computation and parallel prime counting, demonstrating speedups on multicore hardware. Amdahl's Law is introduced to reason about the limits of parallel speedup. (AMP Chapter 1)

## Lecture 02: Mutual Exclusion

This lecture formalises the mutual exclusion problem and explores classical solutions for ensuring that concurrent threads can safely access shared resources. It covers key properties that mutual exclusion protocols must satisfy: mutual exclusion, deadlock-freedom, and starvation-freedom. The lecture presents a progression of algorithms including the LockOne and LockTwo protocols, Peterson's algorithm for two threads, the Filter lock and Bakery algorithm for n threads. Atomic registers and their limitations are discussed, along with the impossibility of solving mutual exclusion with fewer than n read/write registers. All algorithms are implemented in OCaml and tested for correctness. (AMP Chapter 2)

## Lecture 03: Concurrent Objects

This lecture addresses how to formally reason about the correctness of concurrent data structures. It introduces key concepts including quiescent consistency, sequential consistency, and linearizability as correctness conditions for concurrent objects. The lecture discusses the consensus hierarchy, showing that different synchronisation primitives have different consensus numbers, and proves the universality of compare-and-swap (CAS). Progress conditions such as wait-freedom, lock-freedom, obstruction-freedom, and deadlock-freedom are formalised. OCaml implementations of lock-based and lock-free bounded queues are developed and tested using property-based testing with QCheck (linearizability and STM testing). (AMP Chapter 3)

## Lecture 04: Memory Consistency Models

This lecture examines the gap between the idealised shared memory model used in earlier lectures and the reality of modern multiprocessor hardware. It covers why compilers and processors reorder memory operations, introducing store buffers and their effects on program behaviour. The lecture presents sequential consistency (SC) and total store ordering (TSO) as formal memory models, using the store buffer litmus test (SB) and other examples to illustrate observable behaviours under each model. The OCaml memory model is discussed in detail, focusing on data-race-freedom (DRF) guarantees and the distinction between atomic and non-atomic memory accesses. The lecture draws on the OCaml manual's memory model specification and Boehm's "You Don't Know Jack" paper.

## Lecture 05: Spinlocks and Contention

This lecture shifts focus from correctness to performance, revisiting mutual exclusion with realistic hardware models. It covers multiprocessor architectures, cache coherence protocols (MESI), and the distinction between sequential bottlenecks and contention. The lecture presents a progression of increasingly sophisticated spinlock implementations: test-and-set (TAS) lock, test-and-test-and-set (TTAS) lock, exponential backoff lock, and the Anderson array-based queue lock (ALock). Each is analysed for bus traffic, cache behaviour, and scalability. Benchmarks in both OCaml and Java demonstrate the performance characteristics of each lock under varying thread counts. (AMP Chapter 7)

## Lecture 06: Monitors and Synchronization

This lecture covers blocking synchronisation as an alternative to spin-waiting. It motivates the need for blocking when delays are long, contrasting spin-wait (which wastes CPU cycles) with giving up the processor. The lecture introduces condition variables and monitors (mutex + condition variables), tracing back to Hoare's 1973 paper. A bounded blocking queue is developed step by step in OCaml, using condition variables for `not_empty` and `not_full` signalling. The lost wakeup problem is discussed, along with the importance of signalling under the lock. Reader-writer locks are also covered, with both simple and FIFO-fair implementations. (AMP Chapter 8)

## Lecture 07: Linked Lists

This lecture uses concurrent sorted linked lists (implementing sets) as a vehicle to explore a spectrum of synchronisation techniques. Five approaches are covered in progression: coarse-grained locking (one lock for the entire list), fine-grained locking (hand-over-hand per-node locking), optimistic synchronisation (traverse without locks, lock and validate before modifying), lazy synchronisation (mark nodes before physical removal), and lock-free synchronisation using atomic markable references and CAS. Each approach is implemented in OCaml and tested with both unit tests and property-based linearizability/STM tests. The lecture discusses the trade-offs in complexity, throughput, and scalability for each pattern. (AMP Chapter 9)

## Lecture 08: Queues and Stacks

This lecture extends the concurrent data structure patterns to queues and stacks. For queues, it covers bounded lock-based queues (with separate enqueue and dequeue locks for concurrency between producers and consumers), split-counter optimisations, and the Michael-Scott lock-free unbounded queue using CAS on linked list nodes. For stacks, it presents the Treiber lock-free stack using CAS and the elimination-backoff stack, which uses a side channel (elimination array) to allow concurrent push/pop pairs to exchange values directly without touching the shared stack, improving scalability under high contention. OCaml's value representation and the use of `Obj.magic` for type-level tricks are also discussed. (AMP Chapters 10 & 11)

## Lecture 09: Effect Handlers

This lecture marks the transition from parallelism to concurrency, introducing effect handlers as a unified mechanism for non-local control flow in OCaml 5. It motivates the need by surveying how different languages provide concurrency primitives (async/await, generators, coroutines, promises, lightweight threads) and observes that effect handlers can express all of them. The lecture covers the OCaml 5 effect handler syntax, delimited continuations, and the `perform`/`continue`/`discontinue` operations. Examples progress from exception-like recovery to stateful computations (reader, state), nondeterminism, and generators, demonstrating how effects and handlers generalise exceptions by allowing resumption of the suspended computation. (Xavier Leroy's "Control Structures" Chapter 10; OCaml Effect Handlers manual)

## Lecture 10: Lightweight Concurrency

This lecture applies effect handlers to build a Go-like concurrency library from scratch in OCaml. It starts with a uniprocessor scheduler that uses effect handlers to implement cooperative multitasking with fork/yield, then builds synchronisation structures on top: triggers (one-shot wakeup callbacks), IVars (write-once, read-many synchronisation variables), channels (buffered and unbounded, with FIFO ordering), and async/await promises. The key insight is the separation of concerns between the scheduler (which handles suspending and resuming fibers) and synchronisation structures (which are scheduler-agnostic, communicating via `Trigger.Await`). The library is then extended to multicore by using a domain pool with a shared lock-protected FIFO queue, lock-free triggers, and lock-free IVars, achieving actual parallel speedup with sequential cutoffs for nested parallelism. (Xavier Leroy's "Control Structures" Chapter 10)
