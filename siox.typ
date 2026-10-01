// siox: goal and purpose of the language.
// Build: `typst compile siox.typ` (Typst 0.12 or later).

#set document(
  title: "siox: Goal and Purpose",
  author: "The siox project",
)
#set page(
  paper: "a4",
  margin: (x: 2.4cm, y: 2.6cm),
  numbering: "1",
  number-align: center,
)
#set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => block(above: 1.6em, below: 0.9em, text(size: 14pt, it))
#show heading.where(level: 2): it => block(above: 1.3em, below: 0.7em, text(size: 11.5pt, it))
#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: (x: 10pt, y: 8pt),
  radius: 3pt,
  width: 100%,
  text(size: 8.8pt, it),
)
#show raw.where(block: false): it => text(size: 9.5pt, it)

// A short highlighted statement of principle.
#let principle(body) = block(
  inset: (left: 10pt, y: 4pt),
  stroke: (left: 2pt + luma(150)),
  emph(body),
)

#align(center)[
  #v(2.2cm)
  #text(size: 26pt, weight: "bold")[siox]
  #v(0.2cm)
  #text(size: 13pt)[A hardware description language for the whole circuit]
  #v(0.5cm)
  #text(size: 11pt, fill: luma(80))[Goal and purpose · October 2026]
  #v(1.2cm)
]

#block(inset: (x: 1.2cm))[
  #set par(justify: true)
  *Abstract.* siox ("silicon oxide") is a hardware description language and
  compiler. It describes digital circuits with the precise semantics of VHDL
  and the structure of Rust: entities and processes, nine-value IEEE logic and
  delta cycles, written with modules, traits, generics and a single strict type
  system. Designs compile through LLVM to native simulators that run their own
  tests and write VCD or FST waveforms. The digital language is the first of
  three phases: analogue and mixed-signal modelling come next, and then
  turning those models into tool-ready designs. This document explains what
  siox is for, the principles behind it, and where it is going.
]

#v(0.6cm)
#outline(indent: auto, depth: 1)
#pagebreak()

= Why another HDL

Hardware engineers today choose between languages that each solve part of
the problem.

- *VHDL* has the most careful semantics of the mainstream HDLs. Its nine-value
  logic, resolved signals and delta-cycle model describe real circuits
  precisely. Its syntax and its type system were designed in the 1980s, and
  writing reusable, well-structured code in it is laborious.
- *Verilog and SystemVerilog* are concise and universally supported, but their
  semantics are loose: four-value logic, implicit widening and truncation,
  scheduling races between blocks, and a well-known gap between what simulates
  and what synthesizes. SystemVerilog added a large verification language on
  top rather than tightening the design language underneath.
- *Embedded generators* such as Chisel and Amaranth use a general-purpose
  language to build circuits. They gain that language's abstractions, but the
  circuit is a data structure the host program constructs, so errors, types
  and tooling belong to the host, not to the hardware.
- *Newer HDLs* such as Spade and Clash bring modern language design to
  hardware. siox shares their direction and borrows from them where they have
  already solved a problem (Spade's pipelines are one example).

None of them covers more than the digital part of a circuit. A real board
mixes digital logic with analogue parts, power, clocks and the physical
connections between them, and today each of those is described in a
different tool with a different language.

#principle[
  siox aims to be one language for the whole circuit: precise enough to
  simulate digital logic exactly, extensible to analogue behaviour, and
  structured enough to compose both into a design that existing tools can
  build.
]

= Goals

== Hardware semantics first

siox is strict where hardware is strict. Every declaration states its type,
assignment and connection widths must match exactly, and arithmetic does not
widen silently. A signal has one driver unless its type says how parallel
drivers combine. The logic type is the full IEEE 1076-2019 nine-value
`std_ulogic` set (`U X 0 1 Z W L H -`), and uninitialized and conflicting
values propagate through vectors and arithmetic as the standard defines.
Behaviour is checked against an independent reference simulator, not against
siox's own output.

== Two audiences, one language

siox is written to be familiar to two groups at once.

- From *Rust* it takes modules and `use` imports, `pub` visibility, structs
  and enums, traits with generic implementations, `impl` blocks, expression
  syntax, newtypes, and a compiler whose diagnostics and lint levels work like
  rustc's.
- From *VHDL* it takes the hardware model: entities with directional ports,
  concurrent processes with sequential bodies, resolved signals, labels on
  processes and generate blocks, and attributes read with the tick
  (`clk'event`, `x'length`).

Where the two disagree, siox follows Rust for program structure and VHDL for
circuit meaning.

== Three sigils, one job each

The punctuation of the language has fixed meanings:

#table(
  columns: (auto, 1fr, auto),
  stroke: none,
  inset: (x: 6pt, y: 4pt),
  table.header([*Sigil*], [*Meaning*], [*Example*]),
  table.hline(stroke: 0.5pt),
  [`.`], [values: fields and method calls], [`pkt.data`, `clk.rising()`],
  [`::`], [types and modules: paths, variants, associated items], [`std::logic::Bit`, `State::Idle`],
  [`'`], [attributes: properties of a declaration or signal], [`sig'event`, `x'old`, `probe'keep`],
)

== The library over the compiler

Behaviour belongs in source code, not in the compiler. The logic values, their
truth tables, numeric vectors and their operators, time units, encodings and
conversions are declared in siox's standard library as ordinary types and
trait implementations. The compiler provides the mechanisms (type checking,
operator dispatch, elaboration, code generation) and evaluates the library's
definitions; it does not carry a second copy of what `and` means for
`Logic`. A user can define new value types, operators and literal suffixes the
same way the standard library does.

== Tooling that behaves like a modern compiler

`sioxc` is one compiler invocation per file, like `rustc`. It never runs what
it builds. A design compiles to a native object; a file with `#[test]`
entities compiles to a native test executable that runs its testbenches,
filters them by name and writes waveforms. Every diagnostic carries a stable
code, warnings are lints with levels set by `#[allow]`/`#[deny]` or on the
command line, and the same compiler library powers an editor language server.
Output is deterministic: the same source always produces the same IR and the
same simulation.

== Phased, and honest about it

siox grows in phases and never accepts syntax it cannot yet give meaning to.
Analogue constructs are reported as errors in the digital compiler, not
ignored. Features that are designed but not built live as written proposals
until they land.

= A first look

An eight-bit counter with a testbench:

```rust
module counter;

entity Counter {
    clk: Bit in,
    rst: Logic in,
    count: unsigned[8] out,
}

impl Counter {
    let value: unsigned[8] = 0;

    update: process {
        if clk.rising() {            // runs only on a rising clock edge
            if rst == '1' { value = 0; }
            else { value = value + 1; }
        }
    }

    count = value;                   // a wire: always equal to `value`
}

#[test]
entity CounterTest {}

impl CounterTest {
    let clk: Bit = '0';
    let rst: Logic = '1';
    let count: unsigned[8];
    let dut: Counter = { .clk = clk, .rst = rst, .count = count };

    clock: process {
        clk = not clk after 5ns;     // free-running clock, 10 ns period
    }

    stimulus: process {
        await 10ns;                  // hold reset for one edge
        rst = '0';
        for i in 0..9 { await clk.rising(); }
        assert!(count == 10, "counter should reach 10");
    }
}
```

The entity declares the interface; the implementation gives the behaviour. A
concurrent assignment (`count = value;`) is a wire; a process is ordered,
clocked behaviour. The testbench instantiates the counter like a struct,
drives it with timed stimulus and checks it with an assertion. Compiling it
with `sioxc --test counter.siox -o tests` and running `./tests -o run.vcd`
executes the test and records the waveform.

= What the language provides

#table(
  columns: (auto, 1fr),
  stroke: none,
  inset: (x: 6pt, y: 5pt),
  table.hline(stroke: 0.5pt),
  [*Structure*], [Entities and implementations, an instance hierarchy, typed
    ports with directions, struct-shaped buses with directional views,
    parameterized entities, and structural `for`/`if` generation whose labels
    become named scopes (`stages[0].s`).],
  [*Behaviour*], [Concurrent assignments and processes, edge detection built
    from `'event` and `'old`, delta-cycle scheduling, simulation time and
    `await`, and resolved multi-driver nets.],
  [*Types*], [Nine-value logic, arbitrary-width `unsigned`/`signed`, ranged
    integers, real numbers, characters and strings, structs, enums, arrays,
    newtypes and transparent aliases.],
  [*Abstraction*], [Traits with generic implementations, one symbol-parameterized
    operator trait (`Operator<"+", In, Out>`) that also defines new operators,
    user literal prefixes and suffixes (`x"AB"`, `10ns`), and explicit
    conversions.],
  [*Metadata*], [Declared attributes with defaults, bound from outside the
    declaration they describe and read back with the tick; `#[...]` is kept
    for compiler directives such as `#[test]` and lint levels.],
  [*Verification*], [`#[test]` entities, assertions and warnings with source
    locations, formatted printing, deterministic randomization, file fixtures,
    and VCD/FST waveforms.],
  [*Interoperation*], [`extern "C"` functions, an embeddable compiler API, and
    a language server.],
  table.hline(stroke: 0.5pt),
)

= How it works

The compiler is one linear pipeline. Each stage hands the next a complete
product, and each stage keeps going after an error so a single run reports as
much as it can.

#align(center)[
  #set text(size: 9pt)
  #grid(
    columns: 9,
    gutter: 4pt,
    align: center + horizon,
    box(stroke: 0.6pt, inset: 5pt)[parse], [→],
    box(stroke: 0.6pt, inset: 5pt)[resolve], [→],
    box(stroke: 0.6pt, inset: 5pt)[type-check], [→],
    box(stroke: 0.6pt, inset: 5pt)[elaborate], [→],
    box(stroke: 0.6pt, inset: 5pt)[lower],
  )
  #v(2pt)
  #grid(
    columns: 5,
    gutter: 4pt,
    align: center + horizon,
    box(stroke: 0.6pt, inset: 5pt)[process IR], [→],
    box(stroke: 0.6pt, inset: 5pt)[LLVM], [→],
    box(stroke: 0.6pt, inset: 5pt)[native executable + runtime],
  )
]

Elaboration turns parameterized entities into a concrete instance tree.
Lowering produces a digital IR in which combinational drivers and
event-controlled updates stay distinct, and every process, hardware or
testbench, converges on one control-flow representation. That representation
is compiled by LLVM and linked with a small fixed runtime that schedules
processes in delta cycles, advances simulation time and writes waveforms. The
simulator is the program the compiler emits, so a design runs at native speed
with no interpreter in the loop.

= Where siox is going

#principle[Digital and analogue define components. Design connects and realizes them.]

== Phase 1: digital simulation (now)

A strict digital HDL compiling to deterministic native simulation. The
baseline is implemented: the language described above, the standard library,
native test executables, waveforms, diagnostics and editor support. Ongoing
work grows the standard library (synchronizers, memories, FIFOs, numeric
families), the scheduler interface, and integration with verification
frameworks such as cocotb.

== Phase 2: analogue and mixed signal

Continuous quantities without weakening the digital model: analogue domains,
`across`/`through` relationships, derivatives, equation systems and solvers,
and explicit bridges between the digital and analogue worlds with
well-defined event ordering. Analogue models get their own IR and solver
boundary; the digital IR stays exact and event-driven.

== Phase 3: design and synthesis

Turning component models into designs that existing tools can build: a
project and library graph, components written in siox, VHDL or Verilog side
by side, constraints and pin assignments, schematic composition, and a
vendor-neutral, synthesis-facing representation with adapters for tools such
as Vivado, Quartus and Yosys. siox compiles to hardware first; another HDL is
only one way of handing that hardware to a tool.

A separate project tool, in the role Cargo plays for Rust, will own packages
and builds; the compiler stays a single invocation.

= What siox will not be

- A package manager or test runner inside the compiler.
- A digital language whose meaning depends on an analogue solver.
- A home for vendor-specific primitives as language keywords.
- A container for foreign HDL syntax inside siox source.
- A language that accepts constructs it cannot yet give meaning to.

= Summary

siox is a bet that hardware deserves a language with VHDL's precision and
Rust's structure, compiled by a toolchain as dependable as a modern
software compiler, and that the same language can grow from digital logic to
the whole circuit. The digital foundation exists and runs today; the
analogue and design phases build on it without changing what the digital
language means.
