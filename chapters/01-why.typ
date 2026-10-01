#import "../style.typ": *

= Why another HDL

Hardware engineers today choose between languages that each solve part of
the problem.

- *VHDL* has the most careful semantics of the mainstream HDLs. Its nine-value
  logic, resolved signals and delta-cycle model describe real circuits
  precisely. Its syntax and type system date from the 1980s, and writing
  reusable, well-structured code in it is laborious: generics are limited,
  there are no traits or modules in the modern sense, and the tooling around
  it is old.
- *Verilog and SystemVerilog* are concise and universally supported, but their
  semantics are loose: four-value logic, implicit widening and truncation,
  scheduling races between blocks, and a well-known gap between what
  simulates and what synthesizes. SystemVerilog added a large verification
  language on top rather than tightening the design language underneath.
- *Embedded generators* such as Chisel and Amaranth use a general-purpose
  language to build circuits. They gain that language's abstractions, but the
  circuit is a data structure the host program constructs, so errors, types
  and tooling belong to the host, not to the hardware, and simulation is a
  separate world from generation.
- *Newer HDLs* such as Spade and Clash bring modern language design to
  hardware. siox shares their direction and borrows from them where they have
  already solved a problem; Spade's pipelines (@pipelines) are one example.

None of them covers more than the digital part of a circuit. A real board
mixes digital logic with analogue parts, power, clocks and the physical
connections between them, and today each of those is described in a
different tool, in a different language, by a different team.

#principle[
  siox aims to be one language for the whole circuit: precise enough to
  simulate digital logic exactly, extensible to analogue behaviour, and
  structured enough to compose both into a design that existing tools can
  build.
]

== What "the whole circuit" means

The project is organised around one rule:

#principle[Digital and analogue define components. Design connects and realizes them.]

- *Components* are described in the language: a counter, a UART, a PLL
  model, an amplifier stage, a power rail. Digital components exist today;
  analogue components are the second phase.
- *Design* is the act of connecting components into a product and handing it
  to the tools that build it: synthesis for FPGAs and ASICs, netlists and
  schematics for boards, constraints and pin assignments. That is the third
  phase.

Each phase builds on the one before without changing what it means. The
digital language does not become approximate when analogue arrives, and the
design layer does not reinterpret what the components say.

== Who siox is for

- *Hardware engineers* who know VHDL or Verilog and want a language with
  modern structure, strict types and good tools, without giving up the
  hardware model they already think in.
- *Software engineers* moving into hardware, who know Rust's style and need a
  language whose rules catch the mistakes hardware punishes: width
  mismatches, multiple drivers, latches, uninitialised values.
- *Teams* that build boards and systems, not just chips, and today keep the
  digital design, the analogue models and the board in separate worlds.
