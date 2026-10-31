#import "../style.typ": *

= The digital language, growing

Phase 1 is complete: an audit in October 2026 traced every requirement,
deliverable and example to the compiler, the standard library and the test
corpus (`docs/phase1-audit.md` in this paper's repository). It is a
baseline, not a finished language. This chapter describes what is designed and
written down as proposals, in roughly the order it is expected to land. Each
proposal lives in the compiler repository under `docs/proposals/` until it is
built; its substance then moves into the reference documents beside this
paper (`docs/`, starting with the language specification) and the proposal is
deleted. The sections below give every proposal as it stands at the end of
October 2026, including the ones the owner has paused and the open questions
still to be decided.

== Pipelined functions <pipelines>
#status("proposal")

A function is combinational: one clock cycle, however deep its arithmetic. A
pipelined datapath today is an entity written by hand, with a register per
stage per value and the latency known only to its author. siox adopts Spade's
answer: stage boundaries are part of the source, the compiler carries values
across them, and latency is checked at every use. It spells them with two
directives rather than new keywords, because a stage boundary is not new
computation but an instruction about when results are kept.

```siox
#[latched]
fn mac(clk: Bit, a: signed[16], b: signed[16], acc: signed[32]) -> signed[32] {
    #[latch] {                                  // stage 1
        let product: signed[32] = signed[32](sext(a)) * signed[32](sext(b));
    }
    #[latch]                                    // stage 2
    let sum: signed[32] = product + acc;
    return sum;
}

impl Filter {
    #[latched(2)]
    y = mac(clk, x, coefficient, offset);       // mac's result, two cycles later
}
```

- `#[latched]` makes a function a pipeline; its first parameter is the clock.
- `#[latch]` marks one stage: on a block, everything in the block; without
  braces, the one statement that follows. At the end of a stage every value
  it computed or carried is registered, and a `let` inside a stage block stays
  visible after it, one cycle later: a stage is a step in time, not a scope.
- The depth is the number of stages, stated by `#[latched(N)]` and checked
  against the body. Every call site states the depth it expects too, so
  changing a pipeline's depth breaks its users at compile time instead of
  silently shifting their timing by a cycle.
- `#[latch(name = fetch)]` names a stage, and `stage(fetch).x` or
  `stage(-1).x` reads a value in another stage, for forwarding. Using a value
  before the stage that computes it is an error that says how many stages
  early it is.
- `#[latch(enable = cond)]` stalls a stage while `cond` is false, and a stall
  propagates to every earlier stage. `stage'ready` and `stage'valid` say
  whether a stage accepts input and whether its contents are real; valid bits
  start false, because every siox signal starts at its default.

@fig-latency shows what the call site's `#[latched(2)]` promises: each input
reaches `y` two clock edges after it is presented, and one new input enters
every cycle.

#diagram(caption: [The intended timing of `y = mac(…)` with `#[latched(2)]`
(a proposal; not simulated). Before the first result arrives, `y` holds its
type's default.])[
  #wave(
    cells: 16,
    marks: (2, 4),
    axis: ((2, [edge 1]), (4, [edge 2])),
    ([clk], "1010101010101010"),
    ([x], "=.=.=.=.=.=.=.=.", ("x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7")),
    ([y], "=...=.=.=.=.=.=.", ("0", "mac(x0)", "mac(x1)", "mac(x2)", "mac(x3)", "mac(x4)", "mac(x5)")),
  )
] <fig-latency>

The pipeline registers are ordinary registers in the IR and in the eventual
RTL; no backend needs to understand the directives. One naming question is
open: in hardware a *latch* is a level-sensitive element, while these stages
are edge-triggered registers, so `#[pipelined]`/`#[stage]` are possible
alternative names.

== Macros <macros>
#status("done")

Some abstractions generate structure rather than compute values. Macros give
siox a hygienic, declarative way to write them, invoked with `!` so they stay
visibly distinct from calls:

```siox
pub macro debug_signal($name: ident, $ty: type) {
    #[allow(unused_signal)]
    let $name: $ty;
}

impl Cpu {
    debug_signal!(probe, unsigned[32]);
}
```

Implemented, following Rust's declarative macros 2.0:

- Parameters bind syntax fragments (`expr`, `ident`, `type`, `path`, `stmt`,
  `item`, `tokens`), not values, and a macro may have several forms, chosen
  by the arguments.
- A call expands to an expression, statements, implementation members or
  module items, depending on where it stands.
- Expansion happens before name resolution, so generated code is checked
  exactly as if it had been written by hand.
- Hygiene: names a macro declares cannot capture the caller's names, and the
  body's other names mean what they mean where the macro is declared.
- Macros are items, imported with `use`; `--emit expanded` shows what
  hardware a macro produced.
- Repetition unrolls at expansion time: a `$xs: expr...` parameter takes the
  remaining arguments, and `for macro $x in $xs join and { $x }` repeats over
  them.
- An assertion that fails inside a macro reports the line of the call.

- The built-in `assert!`, `warn!`, `print!` and the new fatal `error!` are
  ordinary macros declared in `core`, each over a compiler primitive that
  only `core` may use:

```siox
pub macro assert($cond: expr, $rest: expr...) { builtin # assert($cond, $rest) }
pub macro error($rest: expr...) { builtin # assert(false, $rest) }
```

Still to come is tooling rather than language: a diagnostic inside a nested
expansion should name every invocation that produced it, and editors should be
able to show generated declarations next to the call that made them. Not
proposed: procedural token-stream macros, user-defined `#[...]` attribute
macros, and arbitrary code execution at compile time.

== `core` and `std` <core-std>
#status("done")

The library is split along one question: *could an external library have
written this?*

#table(
  columns: (auto, 1fr),
  table.header([], [*Contents*]),
  table.hline(stroke: 0.5pt),
  [`core`], [What only the compiler can provide, reached through the language:
    the kernel types (`integer`, `real`, `Char`, `Bool`, `string`, `Range`);
    the hook traits the compiler calls (`Add`, `Rem` and the other operators, `CustomOperator`, `Eq`, `Ord`, `Match`,
    `Prefix`, `Suffix`, `Index`, `Boolean`, `Resolve`, `Default`, `From`, `Into`, `Display`, `LogicEncoding`);
    the intrinsics behind `real` math;
    the macros, including a new fatal `error!`; and the
    simulator services (`await`, `stop`, `finish`, files, randomness).
    Compiled into `sioxc`, so it always matches the compiler.],
  [`std`], [Everything a user programs with: `Bit`, `ULogic`, `Logic` and
    their truth tables, `unsigned`/`signed` and conversions, ranged integers,
    `Complex` and math, text encodings, time and frequency, fixed and
    floating point, and, to come, vectors and matrices.],
)

Implemented: `core` is compiled into `sioxc` and laid out like rustc's:
`core::primitive` (`Bool`, `string`, and `integer`'s methods), `core::ops`,
`core::cmp` (`Eq`, `Ord`, `Ordering`, `Match`), `core::convert` (`From`, `Into`),
`core::default` (`Default`), `core::fmt` (`Display`) and `core::macros`; `std` re-exports each module under the same name. The
directives are not declared at all: like rustc's, they are built into the
compiler. Each `core` declaration tells the compiler its role with a lang
item, as rustc's `#[lang = "add"]` does:

```siox
attr lang for Add = "add";
```

The compiler finds its hooks by role and never by path, and only `core` and
`std` may bind `lang`, so a user trait named `Boolean` stays an ordinary
trait. The built-in macros are `core` declarations too (@macros). The `std`
content still to come is listed in the next section.

Metadata follows the same question. `std::attrs` declares only what nearly
every flow needs to know: `keep`, `top`, `clock`, and a foreign entity's
`library` and `name`. Vendor settings (RAM styles, FSM encodings, pin
assignments, I/O standards) belong to vendor packages, namespaced as
`attr vivado::ram_style for …`, so the language never grows a vendor's
vocabulary.

== The standard library
#status("partial")

std is the mandatory, vendor-independent base: data types, conversions and
small helpers every technology has. Memories, FIFOs, stream adapters and
verification components are IP, and belong to vendor packages and libraries.
Each piece comes with documentation and a runnable example:

+ *Synchronizers and reset helpers* #status("done"): `std::sync`'s two-flop
  synchronizer, reset synchronizer, edge detector and pulse synchronizer.
+ *Fixed point* #status("done"): `std::fixed`, after VHDL's `fixed_pkg`, with
  the format as type parameters: `ufixed<8, 4>` has eight bits, four of them
  fraction; arithmetic and division keep the format, and the format's own
  constructor converts a number, `ufixed<8, 4>(2.5)`, or resizes another
  format, `ufixed<12, 6>(x)`, rounding and saturating.
+ *Floating point* #status("partial"): `std::float`, after VHDL's
  `float_pkg`: `float<32, 23>` is IEEE-754 binary32 (32 bits, 23 of them
  mantissa), with addition, subtraction, multiplication, division, square
  root, IEEE comparison (a NaN is unordered), conversions to and from the
  fixed formats, and the constructor `float<32, 23>(1.5)`, rounding to nearest
  even, in processes and in hardware entities alike. Still to come:
  subnormals (flushed to zero today) and the other rounding modes.
+ *Complex numbers* #status("done"): `std::math::Complex`, after
  `ieee.math_complex`, with `+`, `-` and the `i` suffix (`3.0 + 4.0i`).
+ *Linear algebra* (optional): `Vector<T, N>` and `Matrix<T, R, C>` over any
  element with the needed operator traits, as ordinary array-backed library
  types, once a design needs them.

#diagram(caption: [`std::sync::Sync2` in simulation: an input that changes
between clock edges (13 ns) is taken by the first flop on the next edge and
reaches `q` one edge later, so `q` only ever changes on an edge of `clk`.])[
  #wave(
    cells: 70,
    marks: (5, 15, 25, 35, 45, 55, 65),
    axis: ((0, [0]), (10, [10 ns]), (20, [20 ns]), (30, [30 ns]), (40, [40 ns]), (50, [50 ns]), (60, [60 ns])),
    ([clk], "0....1....0....1....0....1....0....1....0....1....0....1....0....1...."),
    ([d], "0............1.......................................0................"),
    ([first flop], "0..............1.......................................0.............."),
    ([q], "0........................1.......................................0...."),
  )
] <fig-sync>

== Entity methods
#status("partial")

An entity's interface is its ports, and a protocol between two entities (offer
a value, learn whether it was taken) is today spread over several ports,
declared twice and wired at every instantiation. Entity methods let a
component expose that protocol once, as a function whose calls *elaborate into*
ports, following Bluespec's method-to-port mapping:

```siox
impl Fifo {
    pub fn write(self, value: unsigned[8]) -> Bool { … }
}

impl Producer {
    if clk.rising() {
        if f.write(value) { value = value + 11; }
    }
}
```

A call materialises an enable port, one port per argument and one for the
result; nothing is hidden, and the generated ports cost exactly what
hand-written ones do. The first version allows one call site per method per
instance, so no arbitration is needed. A call through an instance array works
the same way: `stage[sel].write(v)` gives every element its own enable, gated by
`sel`, so each still has one caller.

Associated functions without a receiver are implemented. Accessors and action
methods are #status("on hold"): the owner paused them in October 2026, because
an entity's body names its ports and state without a receiver, and a `self`
parameter on an entity method would look unlike everything else in that body.
The implicit-receiver proposal below answers that objection; whether the two
land together is the proposal's open question.

== Implicit receivers and `static`
#status("proposal")

Today a `self` parameter is what tells a method from an associated function.
The proposal makes that distinction a keyword instead, the same for structs,
enums, entities and views:

#table(
  columns: (auto, auto),
  table.header([*Declared in an implementation*], [*Receiver*]),
  table.hline(stroke: 0.5pt),
  [`fn f(...)`, `pub fn f(...)`], [implicit `self`],
  [`static fn f(...)`, `pub static fn f(...)`], [none: called as `Type::f(...)`],
)

```siox
impl Counter {
    pub fn increment() { value = value + 1; }         // fields by name
    pub fn set(value: integer) { self.value = value; } // `self.` when shadowed
    pub static fn from_count(value: integer) -> Counter {
        return Counter { .value = value };
    }
}
```

`self` stays as an expression and `Self` as the implementing type; `pub`
controls only visibility. Constructors and conversions become explicitly
static (`static fn default() -> Self`, `static fn from(value: S) -> Self`).
The migration has to be loud: a receiver-free `fn` in an implementation means
an associated function today and would gain a receiver, so old code must fail
with a message rather than change meaning.

The proposal also adds `static let`, state that outlives one activation of a
process. Its rules are being decided (October 2026):

- It is allowed in processes and functions, and an error in an entity body,
  where every `let` is already a signal declared once.
- The proposed semantics are a *signal scoped to its process*: it updates like
  every siox signal (a write takes effect at the end of the step), its
  initializer is its power-on value, and it is named by the process label for
  waveforms and debugging. That keeps the variable/signal split of VHDL and
  the blocking/non-blocking split of Verilog out of the language: nothing is
  inferred, the `static` is written.
- In a function, the proposal is one copy per call site, as hardware inlines
  each call (two calls of a stateful `debounce` are two debouncers), and an
  error in a recursive function.

It overlaps scoped blocks (below): `static let` is the lighter form for state
one process owns, a block for state several processes share.

== Scoped blocks
#status("proposal")

A large implementation collects all its state in one namespace. A `{ … }` block
at implementation scope groups members under their own scope, with an
optional label:

```siox
impl Cpu {
    counter: {
        let n: unsigned[8] = 0;          // private to the block
        pub let wrapped: Bit = '0';      // visible to the whole implementation
        step: process {
            if clk.rising() {
                n = n + 1;
                wrapped = if n == 255 { '1' } else { '0' };
            }
        }
    }
    overflow = counter.wrapped;          // a pub member, through the label
}
```

Names follow Rust's block scoping; a private member from outside is an error
naming the block. `pub` exports one level and never past the entity, whose
interface stays its ports. A labelled block is a scope in the hierarchy, as a
generate label is (`counter.n` in the tree, waveforms and debugger); an
unlabelled one adds no level. Blocks add no semantics: elaboration flattens
them, and no register is ever inferred from a local.

== Payload enums
#status("on hold")

Variants that carry data, as in Rust, for optional and fallible results,
protocol messages and state machines with per-state data:

```siox
pub enum Option<T> { None, Some(T) }
enum Command {
    Idle,
    Read(unsigned[16]),
    Write { addr: unsigned[16], data: unsigned[32] },
}

match c {
    Command::Idle => ready = '1',
    Command::Read(addr) => q = memory[addr],      // binds `addr`
    Command::Write { addr, data } => memory[addr] = data,
}
```

A payload enum is a tag plus a payload region as wide as its largest variant,
the variants overlaid as in a SystemVerilog tagged union; a field is in scope
only inside its variant's arm, so another variant's bits are never read.
Patterns that bind (`Some(x)`) are the first of their kind and the largest
piece of work; the match coverage proofs that exist already extend to
variants. std would gain `Option`, `Result` and `checked_add`.

The rule agreed in October 2026 keeps it apart from the logic system. An enum
is either a *value enum*, today's kind, whose variants may be characters or
carry explicit discriminants (`'U' = 4`, `Add = 0`), or a *sum type*, whose
variants may carry data and whose tag the compiler chooses. A character or
numbered variant has no payload, as in Rust a variant with an explicit
discriminant has none, so `Bit`, `ULogic`, `Logic` and every character enum
keep their representation. A character literal inside a payload takes its type
from context (`let b: Option<Bit> = Some('1');`). The owner has paused the
proposal; the open questions are what unused payload bits hold (`'0'` or
`'-'`), a checked accessor, and dropping the tag for a niche, as Rust's
`Option<&T>` does.

== Binary and unary custom operators
#status("proposal")

`CustomOperator` is binary only. The proposal splits it into two contracts
with explicit arity, so prefix operators can be declared too:

```siox
impl BinaryOperator<"clip", unsigned, unsigned[3]> for unsigned {
    attr precedence = 35;
    fn apply(rhs: unsigned) -> unsigned[3] { return unsigned[3](self + rhs); }
}
impl UnaryOperator<"flip", Logic> for Logic {
    fn apply() -> Logic { … }                      // `flip a`
}
```

The declared result keeps its width, range and alias identity through a chain,
which `CustomOperator` already does. The standard operator traits (`Add`,
`Not`, `Neg`, …) and the comparisons are unchanged, and an old declaration
fails with a migration message instead of being reinterpreted.

== The last implicit conversion site
#status("partial")

`Into` converts at a `let`, an assignment, an argument, a returned value and a
struct-literal field. A port connection is the remaining site: connecting an
`unsigned[8]` signal to a `Logic[8]` port should convert as storing it does.
It waits for the checker to type a connection against its port, which is in
progress.

== Compiler foundations
#status("partial")

Changes borrowed from rustc's architecture, each independent. Lang items
(@core-std) have landed: `core` marks the declarations the compiler hooks
into, and the compiler finds them by role. The rest remain:

+ *UI tests*: every diagnostic pinned by a snapshot test, with inline
  `//~ ERROR` annotations and a `--bless` mode.
+ *Diagnostics for tools*: `--explain E-P014`, JSON output, and fix
  suggestions that a `--fix` mode can apply, making every future syntax
  migration one command.
+ *One constant evaluator* shared by every stage, replacing more than a dozen
  that grew separately, several of them added by bug fixes that each needed
  constants in one more place.
+ *A resolved tree* between type checking and elaboration, so later stages
  work with declaration identities and registries rather than re-reading the
  syntax.
+ *No name lookups after resolution*: the last few hooks still found by
  spelling move to lang items and resolved identities.

None of the five has landed yet (October 2026); each lands on its own.

== Parallel simulation <parallel>
#status("proposal")

A design has many processes, and today one host thread runs them all: the
fixed runtime acts like a small cooperative scheduler, running a process until
it suspends, settles or finishes, then the next. The proposal keeps that model
and adds a bounded pool of worker threads that run, within one delta cycle,
only process slices proven independent of each other. Effects are isolated
and merged in a fixed order, so a run with any number of threads produces the
same results, diagnostics and waveforms as a run with one; anything not proven
independent falls back to serial execution. The thread count is an option of
the test executable (`--threads N`), not of the compiler, and the same Process
IR, native entries and runtime serve both modes. No new language construct is
needed.

The unit of work is an *epoch*: the processes ready at one simulation time
and publication boundary. On one thread they run one after another in a fixed
reference order, process by process. With workers, the coordinator splits that
ordered list into batches that may run side by side, and anything with an
effect it cannot isolate (a file read, a random draw, a print, a write another
process reads straight away) runs alone in its place in the order
(@fig-epoch). Speed comes only from the batches; the order of the results
never changes.

#diagram(caption: [One epoch on one thread and on three lanes. P4 reads a
file, so it runs alone, between the batches before and after it. The
coordinator merges every slice's effects in process order before publishing,
so both runs end in the same state.])[
  #text(size: 8pt, weight: "bold")[One thread]
  #lanes(
    slots: 14,
    ([lane 1], (
      (0, 2, [P1], c-back), (2, 2, [P2], c-back), (4, 2, [P3], c-back),
      (6, 2, [P4 · file], c-run), (8, 2, [P5], c-back), (10, 2, [P6], c-back),
      (12, 2, [publish], c-muted),
    )),
  )
  #v(6pt)
  #text(size: 8pt, weight: "bold")[Three lanes (#mono("--threads 3"))]
  #lanes(
    slots: 14,
    marks: (2, 4, 6),
    axis: ((0, [batch 1]), (2, [alone]), (4, [batch 2]), (6, [merge])),
    ([coordinator], (
      (0, 2, [P1], c-back), (2, 2, [P4 · file], c-run), (4, 2, [P5], c-back),
      (6, 3, [merge · publish], c-muted),
    )),
    ([worker], ((0, 2, [P2], c-back), (4, 2, [P6], c-back))),
    ([worker], ((0, 2, [P3], c-back),)),
  )
  #v(2pt)
  #text(size: 7.6pt, fill: luma(80))[Host time runs left to right; simulation
  time does not move during an epoch.]
] <fig-epoch>

Whether two slices may share a batch is decided before they run, from effect
summaries the compiler derives from each process's control-flow graph: which
signals it reads, which storage it writes, what it schedules, and whether it
touches the host (@fig-dispatch). Anything unknown counts as a conflict.

#diagram(caption: [How the proposed runtime dispatches an epoch. Only slices
proven independent reach the workers; everything else keeps its serial place.
The merge and publication steps are the ones a single thread already
performs.])[
  #align(center, grid(
    columns: 2,
    align: center + horizon,
    column-gutter: 28pt,
    row-gutter: 5pt,
    grid.cell(colspan: 2, step(colour: c-run)[the ready slices of this epoch, in process order]),
    grid.cell(colspan: 2, arrow("down")),
    grid.cell(colspan: 2, step(colour: c-ir)[compare effect summaries: reads, writes,\ schedules, host services]),
    arrow("down-left", label: [proven independent]),
    arrow("down-right", label: [dependent, unknown or host effects]),
    step(colour: c-back)[run as one batch on the lanes;\ each slice buffers its own effects],
    step(colour: c-run)[run alone on the coordinator,\ in its place in the order],
    arrow("down-right"), arrow("down-left"),
    grid.cell(colspan: 2, step(colour: c-run)[merge effects in order: epoch, process, effect number]),
    grid.cell(colspan: 2, arrow("down")),
    grid.cell(colspan: 2, step(colour: c-run)[publish writes and events, settle: as on one thread]),
    grid.cell(colspan: 2, arrow("down")),
    grid.cell(colspan: 2, step(colour: c-muted)[the next epoch, or advance time]),
  ))
] <fig-dispatch>

== Co-simulation and the simulator interfaces
#status("proposal")

Today a siox design runs only in its own executable. Two things a hardware team
needs go through the same two IEEE interfaces in opposite directions: VPI
(Verilog and SystemVerilog) and VHPI (VHDL).

- *siox as a client:* `sioxc` builds a siox top as a shared library plus a
  wrapper module or entity in Verilog and VHDL. A host simulator instantiates
  the wrapper like any other block, and the library, loaded as its VPI or VHPI
  plugin, steps the siox runtime from the host's callbacks. VHDL first, on
  nvc; Verilog second, on Icarus.
- *siox as a server:* the siox executable implements VPI, then VHPI, so
  external tools attach to it. cocotb is the first client, for Python
  testbenches.

Both rest on one refactor: the test runner's loop split into steps an outside
scheduler can drive (start, apply inputs, settle, advance time, read outputs),
with the `--test` executable as one driver of it. Values crossing follow the
interoperability rules: logic is exact through VHPI and normalized to
`X01Z` for four-state VPI. No language change is needed. The cocotb work was
deferred in October 2026, when the API work closed; the proposal stays the
design for when it resumes, and the same steppable runtime will serve the
mixed-signal coordination of Phase 2.
