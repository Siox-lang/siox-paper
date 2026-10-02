#import "../style.typ": *

= Tools, boundaries and status

== The tools around the compiler

- *`sioxc`* is the compiler: one invocation per file, producing an object, a
  test executable or an inspection output. It is not a package manager or a
  test runner, and never will be.
- *A project tool* #status("planned"), in the role Cargo plays for Rust, will
  own projects, packages, dependencies and builds, calling `sioxc` underneath.
  It lives in its own repository.
- *`siox-lsp`* #status("done") gives editors live diagnostics, navigation,
  completion and rename, using the compiler as a library.
- *The test corpus* #status("done") is a separate repository of runnable siox
  programs that every compiler change must pass, in both of the compiler's
  build configurations.
- *Syntax highlighting* #status("done") for siox code ships as a Sublime
  syntax definition (used by this document, Sublime Text and `bat`), coloured
  the way One Dark Pro colours Rust.

== What siox will not be

- A package manager or test runner inside the compiler.
- A digital language whose meaning depends on an analogue solver.
- A home for vendor-specific primitives as language keywords.
- A container for foreign HDL syntax inside siox source.
- A language with conditional compilation that can hide code from the type
  checker; target selection is a value that both branches are checked
  against.
- A language that accepts constructs it cannot yet give meaning to.

== How siox compares

#table(
  columns: (auto, 1fr, 1fr, 1fr, 1fr),
  table.header([], [*VHDL*], [*SystemVerilog*], [*Chisel*], [*siox*]),
  table.hline(stroke: 0.5pt),
  [Logic values], [nine-value `std_logic`], [four-value], [two-value], [nine-value IEEE, as library code],
  [Widths], [strict], [implicit widening and truncation], [inferred], [strict; no implicit widening],
  [Multiple drivers], [resolved types], [net resolution], [last connection wins], [only with a `Resolve` impl],
  [Abstraction], [generics, packages], [classes, interfaces], [Scala], [traits, generics, views, operators as traits],
  [Simulation], [external event-driven simulators], [external event-driven simulators], [through generated Verilog], [native code from the compiler],
  [Testing], [testbench entities], [testbench modules and classes], [Scala test frameworks], [`#[test]` entities, test executables],
  [Beyond digital], [VHDL-AMS, a separate standard], [—], [—], [analogue (Phase 2) and design (Phase 3) in one language],
)

== Where things stand

#table(
  columns: (1fr, auto),
  table.header([*Area*], [*Status*]),
  table.hline(stroke: 0.5pt),
  [Modules, `use`/`type` with Rust's import forms, visibility], [#status("done")],
  [Entities, implementations, instances, views, generics], [#status("done")],
  [Structural generation with labelled scopes], [#status("done")],
  [Processes, wires, delta cycles, events, clocks, time], [#status("done")],
  [Nine-value logic, metavalues, numeric vectors, ranged integers], [#status("done")],
  [Traits, operator traits, custom operators, literal affixes], [#status("done")],
  [Declared attributes, directives, lint levels], [#status("done")],
  [Testbenches, test executables, VCD/FST waveforms], [#status("done")],
  [`extern "C"`, compiler API, language server], [#status("done")],
  [Entity methods], [#status("partial")],
  [Standard-library build-out], [#status("partial")],
  [User macros], [#status("partial")],
  [`core`/`std` split, lang items], [#status("partial")],
  [Pipelined functions, `derive`], [#status("proposal")],
  [Compiler foundations (UI tests, JSON, lang items)], [#status("proposal")],
  [Simulator interface and cocotb], [#status("planned")],
  [Analogue and mixed signal], [#status("phase2")],
  [Projects, foreign HDL, constraints, vendor-neutral RTL, synthesis], [#status("phase3")],
)

== Summary

siox is a bet that hardware deserves a language with VHDL's precision and
Rust's structure, compiled by a toolchain as dependable as a modern software
compiler, and that the same language can grow from digital logic to the whole
circuit. The digital foundation exists and runs today. The analogue and
design phases build on it without changing what the digital language means.
