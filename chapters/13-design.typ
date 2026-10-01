#import "../style.typ": *

= Phase 3: design and synthesis
#status("phase3")

The third phase turns component models into designs that existing tools can
build. Components are what Phases 1 and 2 describe; *design* is connecting
them into a product and realising it.

== Projects and libraries

A real design is many files, libraries and vendors' IP. Phase 3 adds a project
and package graph: reusable libraries with versions, discovered by name. The
language names libraries and entities without saying whether their
implementation is siox, VHDL, Verilog or a vendor database; that choice
belongs to the project, not to the source. An instance of a vendor PLL and an
instance of a siox counter are written the same way.

== Foreign HDL, side by side

Most designs will mix siox with existing VHDL and Verilog: a vendor's IP core,
a legacy block, a third-party interface. siox elaborates such a design with
the foreign components as black boxes whose interface, metadata and library
are known, links them by library metadata, and carries their names, widths,
directions and clocks through to the output. Foreign HDL syntax never appears
inside siox source, and compiling foreign HDL inside `sioxc` is only on the
table if no existing compiled format can supply what is needed.

== Constraints and physical intent

Clocks and their frequencies, I/O standards, pin assignments, placement and
the vendor attributes of @core-std are declared in the language, attached
with `attr` bindings to the ports and instances they describe, checked
against their declarations, and exported to each tool in its own format.

== Synthesis through a vendor-neutral RTL
#status("proposal")

siox compiles to hardware before it compiles to another HDL. The design is
lowered into a vendor-neutral, synthesis-facing RTL representation that
describes elaborated hardware directly:

#table(
  columns: (auto, 1fr),
  table.header([*Object*], [*What it records*]),
  table.hline(stroke: 0.5pt),
  [modules, ports, instances], [the elaborated hierarchy, with directions, widths and names],
  [registers], [clock, edge, reset kind and polarity, enable, next value],
  [memories], [width, depth and read/write ports, kept intact so tools infer block RAM],
  [operations], [`add`, `mul`, `mux`, comparisons with known widths and signedness, kept intact so tools map multipliers to DSP blocks],
  [clock and reset domains], [explicit, for CDC analysis, constraints and timing],
  [metadata], [vendor-neutral attributes such as `keep`, with vendor-specific ones namespaced],
  [provenance], [the source location and the construct (a macro, a pipeline) that produced each node],
)

By the time a design reaches this representation, nothing of the source
language is left to interpret: traits are resolved, generics specialised,
macros expanded, attributes looked up, and pipelines turned into explicit
registers. A backend only serialises:

- *SystemVerilog*, first, as a small, conservative subset that every tool
  accepts: modules, `always_ff`, `assign`, instances. The output reads like
  RTL assembly, not like hand-written code.
- *VHDL*, from the same representation, describing equivalent hardware.
- *CIRCT* and *Yosys*, where their own representations are a better fit.

A legalization step adapts the representation to each backend's subset; it
changes form, never meaning, and a backend that cannot represent something
faithfully says so rather than reinterpreting the design. `--emit rtl` shows
the representation, answering the question every engineer asks of a
high-level HDL: what hardware did it actually generate?

Simulation-only constructs (testbench `await`, file reads while running,
random numbers, `after` delays) are reported when compiling for synthesis.
Whether a construct may appear in hardware is answered per declaration by the
target, not by excluding a library.

== Schematics and boards

The last step is the board. Composing components into a netlist or schematic,
with graphical tooling where it helps, connects the digital and analogue
models of Phases 1 and 2 to the physical product, and keeps diagnostics,
waveforms and debugging correlated with the source throughout.

== How it will be judged

Phase 3 is done when a design containing siox and foreign components
elaborates, emits a stable vendor-neutral artifact that preserves hierarchy,
names, widths, directions, clocks and constraints, and that artifact goes
through at least two synthesis ecosystems, with enough metadata coming back to
correlate their reports with the source.
