#import "../style.typ": *

= The compiler

== One pipeline
#status("done")

`sioxc` is one Rust crate: a library of stages and a thin command-line
driver. Each stage hands the next a complete product, and each stage keeps
going after an error so a single run reports as much as it can.

#table(
  columns: (auto, 1fr),
  table.header([*Stage*], [*What it does*]),
  table.hline(stroke: 0.5pt),
  [parse], [Tokens and a syntax tree for every module the program imports, transitively.],
  [expand], [User macros expanded where they are called, and `#[derive]` impls written into their struct's module.],
  [attributes], [Attach `attr` bindings to their targets and fold attribute reads into values; collect lint levels.],
  [resolve], [Every name to the declaration it means: modules, imports, visibility, paths.],
  [type-check], [Types, widths, directions, trait bounds, operator dispatch, conversions.],
  [elaborate], [Parameters substituted and generation unrolled into a concrete instance tree.],
  [lower], [A digital IR: signals, combinational drivers, event-controlled updates, and one control-flow form for every process.],
  [codegen], [LLVM, then a native object or test executable linked with a fixed runtime.],
)

#diagram(caption: [The pipeline. The front end produces one checked instance
tree; hardware and testbench processes alike become Process IR; the native
code links with a runtime that is the same for every design.])[
  #flow(
    step(colour: c-front)[parse],
    step(colour: c-front)[expand],
    step(colour: c-front)[attributes],
    step(colour: c-front)[resolve],
    step(colour: c-front)[type-check],
    step(colour: c-front)[elaborate],
  )
  #arrow("down")
  #flow(
    step(colour: c-ir)[lower to\ Process IR],
    step(colour: c-back)[LLVM\ codegen],
    step(colour: c-back)[design\ object],
    step(colour: c-run)[link with the\ fixed runtime],
    step(colour: c-back)[test executable:\ results, VCD, FST],
  )
] <fig-pipeline>

The digital IR keeps one distinction from VHDL's model at its centre: a
*driver* (a wire: `target = expr` under a condition) and an *event block*
(`on condition: next(target) = expr`) are different things, and `'event` and
`'old` are first-class operations. Hardware processes and testbench processes
both converge on one control-flow representation, validated before code
generation, so there is one path from source to executable and one meaning.

== Native simulation
#status("done")

The compiler does not interpret designs. It emits the design as native code
and links it with a small runtime, fixed and independent of the design, that
schedules processes in delta cycles, advances simulation time, applies delayed
writes with inertial semantics, and writes VCD and FST. A simulation is
therefore a native program, with no interpreter in the loop.

== Diagnostics
#status("done")

Every diagnostic has a stable code (`E-P014` is a conflicting driver,
`W-P002` a possible latch), a primary location, labelled secondary locations,
notes and a suggested fix. Migration errors say exactly what to write instead:

```text
error: `using` was split into `use` and `type`; this is a type alias
  --> design.siox:3:1
   = help: write `pub type Word = unsigned[32];` (`type`)
```

Warnings are lints whose levels are set in source or on the command line
(@lints). The compiler prefers no error over a wrong one: where it cannot yet
decide something soundly, it stays silent.

== C functions <extern-c>
#status("done")

C libraries connect through extern blocks, as in Rust:

```siox
extern "C" {
    pub fn cbrt(x: real) -> real;      // from the C math library
    pub fn labs(v: integer) -> integer;
}
```

`real` crosses as `double`, `integer` as a 64-bit signed word, packed numeric
values up to 64 bits as an unsigned word, and `std::ffi`'s `c_int`, `c_short`,
`c_float` and the others at their C widths. A function without a return type
is C `void`, a statement a testbench runs in order. A struct or fixed array of
C scalars is passed by pointer to a C-laid-out copy, which the caller receives
back (an out-parameter); wider values cross as little-endian words. Calls work
in hardware expressions, clocked updates and testbenches, and a test
executable links any object given with `--link`. The standard library does not
use C: its `real` math (`sqrt`, `sin`, …) is compiler intrinsics, so a design
never depends on a host library it did not ask for.

== Embedding and editors
#status("done")

The compiler is a library first. `siox::compiler` takes a request (a file or
an unsaved editor buffer, and the artifact wanted) and returns every product
it produced: modules, resolution, types, the instance tree, the IR, and the
diagnostics. The command-line driver is a thin adapter over it, and the
`siox-lsp` language server, in its own repository, uses the same library for
live diagnostics, go-to-definition, hover, completion and rename, so editor
and compiler never disagree.

Inspection outputs show each stage: `--emit tokens`, `ast`, `source` (the
canonical printed form, also the migration tool), `expanded` (after macros
and derives), `tree` (the instance hierarchy), `metadata`, `ir` and
`llvm-ir`. `-g` adds DWARF so GDB steps the siox source (see Verification).
