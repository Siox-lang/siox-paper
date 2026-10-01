#import "../style.typ": *

= Principles

== Hardware semantics first

siox is strict where hardware is strict.

- Every declaration states its type. `let x = e;` without a type is an error.
- Assignment and connection widths must match exactly, and arithmetic does not
  widen silently: `unsigned[8] + unsigned[8]` wraps at eight bits. Widening and
  narrowing are written as conversions.
- A signal has one driver unless its type says how parallel drivers combine.
  Two drivers of an unresolved signal are an error that points at both.
- The logic type is the full IEEE 1076-2019 nine-value `std_ulogic` set
  (`U X 0 1 Z W L H -`), and uninitialized and conflicting values propagate
  through vectors and arithmetic as the standard defines.
- Every signal starts at a defined value: its type's default. A `Logic` starts
  at `'U'`, so an undriven signal reads as uninitialized rather than as a
  plausible `'0'`.

Behaviour is checked against an independent reference simulator (nvc for
VHDL semantics), not against siox's own output.

== Two audiences, one language

siox is written to be familiar to two groups at once.

- From *Rust* it takes modules and `use` imports, `pub` visibility, structs
  and enums, traits with generic implementations, `impl` blocks, expression
  syntax including `if` and `match` as expressions, newtypes, and a compiler
  whose diagnostics and lint levels work like rustc's.
- From *VHDL* it takes the hardware model: entities with directional ports,
  concurrent processes with sequential bodies, resolved signals, labels on
  processes and generate blocks, and attributes read with the tick
  (`clk'event`, `x'length`).

Where the two disagree, siox follows Rust for program structure and VHDL for
circuit meaning. When siox's intended behaviour is unclear, the first question
is what rustc does, and the answer stops where hardware starts.

== Three sigils, one job each

The punctuation of the language has fixed meanings:

#table(
  columns: (auto, 1fr, auto),
  table.header([*Sigil*], [*Meaning*], [*Example*]),
  table.hline(stroke: 0.5pt),
  [`.`], [values: fields and method calls], [`pkt.data`, `clk.rising()`],
  [`::`], [types and modules: paths, variants, associated items], [`std::logic::Bit`, `State::Idle`],
  [`'`], [attributes: properties of a declaration or signal], [`sig'event`, `x'old`, `probe'keep`],
)

A reader can tell from the punctuation alone whether an expression reads a
value, names a type, or asks a question about a declaration.

== The library over the compiler

Behaviour belongs in source code, not in the compiler. The logic values, their
truth tables, numeric vectors and their operators, time units, encodings and
conversions are declared in the standard library as ordinary types and trait
implementations. The compiler provides the mechanisms (type checking,
operator dispatch, elaboration, code generation) and evaluates the library's
definitions; it does not carry a second copy of what `and` means for `Logic`.
A user can define new value types, operators and literal suffixes the same
way the standard library does.

The rule cuts the other way too: what only the compiler can do belongs to the
compiler, and is reached through the language in a small, fixed set of
places: directives, macros, and the hooks the standard library implements
(@core-std).

== Tooling that behaves like a modern compiler

`sioxc` is one compiler invocation per file, like `rustc`. It never runs what
it builds. A design compiles to a native object; a file with `#[test]`
entities compiles to a native test executable that runs its testbenches,
filters them by name and writes waveforms. Every diagnostic carries a stable
code, warnings are lints with levels set by `#[allow]`/`#[deny]` or on the
command line, and the same compiler library powers an editor language server.

== Deterministic

The same source always produces the same IR, the same object and the same
simulation, on every machine and every run. Simulation order inside a delta
cycle never depends on hash order or thread timing, randomization is seeded
and reproducible, and the corpus of example programs is checked for
byte-identical output between runs.

== Phased, and honest about it

siox grows in phases and never accepts syntax it cannot yet give meaning to.
Analogue constructs are reported as errors in the digital compiler, not
ignored. Features that are designed but not built live as written proposals
until they land, and removed syntax is an error that names its replacement
(`process name { … }` became `name: process { … }`, `using` became `use` and
`type`).
