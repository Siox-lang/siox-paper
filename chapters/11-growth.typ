#import "../style.typ": *

= The digital language, growing

Phase 1 is a working baseline, not a finished language. This chapter describes
what is designed and written down as proposals, in roughly the order it is
expected to land. Each proposal lives in the compiler repository under
`docs/proposals/` until it is built, and is then folded into the language
specification.

== Pipelined functions <pipelines>
#status("proposal")

A function is combinational: one clock cycle, however deep its arithmetic. A
pipelined datapath today is an entity written by hand, with a register per
stage per value and the latency known only to its author. siox adopts Spade's
answer: stage boundaries are part of the source, the compiler carries values
across them, and latency is checked at every use.

```siox
#[pipeline(3)]
fn mac(clk: Bit, a: signed[16], b: signed[16], acc: signed[32]) -> signed[32] {
    let product: signed[32] = signed[32](sext(a)) * signed[32](sext(b));
    reg;                                  // stage boundary: everything above is registered
    let sum: signed[32] = product + acc;
    reg * 2;
    return sum;
}

impl Filter {
    #[pipeline(3)]
    y = mac(clk, x, coefficient, offset);  // y is mac's result three cycles later
}
```

- `#[pipeline(N)]` declares the depth, and the number of `reg` boundaries on
  every path must match it.
- Every call site states the depth it expects. Changing a pipeline's depth
  therefore breaks its users at compile time instead of silently shifting
  their timing by a cycle.
- Stages take VHDL-style labels (`execute: reg;`), and `stage(execute).x` or
  `stage(-1).x` reads a value in another stage, for forwarding. Using a value
  before the stage that computes it is an error that says how many stages
  early it is.
- `reg[cond];` stalls a stage while `cond` is false, and a stall propagates to
  every earlier stage. `stage'ready` and `stage'valid` say whether a stage
  accepts input and whether its contents are real; valid bits start false,
  because every siox signal starts at its default.

The pipeline registers are ordinary registers in the IR and in the eventual
RTL; no backend needs to understand the directive.

== Macros
#status("proposal")

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

- Parameters bind syntax fragments (`expr`, `ident`, `type`, `stmt`, `item`,
  `path`), not values.
- Expansion happens before name resolution, so generated code is checked
  exactly as if it had been written by hand.
- Hygiene: names a macro introduces cannot capture the caller's names.
- Errors point at both the generated code and the invocation; an
  expanded-source output shows what hardware a macro produced.
- Not proposed: procedural token-stream macros, user-defined `#[...]`
  attribute macros, and arbitrary code execution at compile time.

The built-in `assert!`, `print!` and `warn!` become ordinary macros declared
in the language core, backed by compiler builtins.

== `core` and `std` <core-std>
#status("proposal")

Today one standard library holds two kinds of declaration. The proposal splits
them along one question: *could an external library have written this?*

#table(
  columns: (auto, 1fr),
  table.header([], [*Contents*]),
  table.hline(stroke: 0.5pt),
  [`core`], [What only the compiler can provide, reached through the language:
    the kernel types (`integer`, `real`, `Char`, `Bool`, `string`, `Range`);
    the hook traits the compiler calls (`Operator`, `Ordering`, `Prefix`,
    `Suffix`, `Index`, `Boolean`, `Resolve`, `New`, `From`, `LogicEncoding`);
    the directives; the macros, including a new fatal `error!`; and the
    simulator services (`await`, `stop`, `finish`, files, randomness).
    Compiled into `sioxc`, so it always matches the compiler.],
  [`std`], [Everything a user programs with: `Bit`, `ULogic`, `Logic` and
    their truth tables, `unsigned`/`signed` and conversions, ranged integers,
    `Complex` and math, text encodings, time and frequency, and, to come,
    vectors and matrices, fixed-point families and reusable hardware.],
)

`std` also gains vendor-neutral spellings for the metadata every synthesis
flow wants, mapped by each backend to its vendor's name: `keep`, `async_reg`,
`ram_style`, `rom_style`, `fsm_encoding`, `max_fanout`, `mark_debug`, clock
frequencies, I/O standards and pin assignments.

== The standard library
#status("partial")

The standard library will grow, in this order, each piece with documentation
and a runnable example:

+ *Synchronizers and reset helpers*: two-flop synchronizers, reset
  synchronizers, edge and pulse helpers with explicit clock domains.
+ *Memories*: synchronous single- and dual-port RAM shapes, initialised from
  arrays or files, with defined collision behaviour.
+ *Streams and FIFOs*: canonical ready/valid structs and views, skid buffers,
  pipeline registers, width adapters, synchronous then asynchronous FIFOs.
+ *Numeric families*: fixed-point `ufixed`/`sfixed` with explicit saturation
  and rounding, and conversions to integers and reals.
+ *Linear algebra*: vectors and matrices over any numeric element.
+ *Verification helpers*: scoreboards and monitors, once the simulator's
  external interface is stable.

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
hand-written ones do. Associated functions without `self` are implemented;
pure accessors and action methods with arguments come next.

== Imports, `derive` and the rest of the type system
#status("proposal")

- The remaining Rust import forms: nested groups, `self` in groups, glob
  imports, `self::`/`super::` paths, block-scoped imports, generic `type`
  aliases, and separate namespaces for types, values and macros.
- `#[derive(Ord)]` and `#[derive(Resolve)]` generating the routine
  implementations, once a second real use exists.
- Compile-time selection stays a *value*, `std::target`, never `#[cfg]`: both
  branches are always type-checked, and there is one IR.

== Compiler foundations
#status("proposal")

Five changes borrowed from rustc's architecture, each independent:

+ *UI tests*: every diagnostic pinned by a snapshot test, with inline
  `//~ ERROR` annotations and a `--bless` mode.
+ *Diagnostics for tools*: `--explain E-P014`, JSON output, and fix
  suggestions that a `--fix` mode can apply, making every future syntax
  migration one command.
+ *One constant evaluator* shared by every stage, replacing several that grew
  separately.
+ *No name lookups after resolution*: later stages work only with resolved
  declaration identities, never with spellings.
+ *Lang items*: the standard library marks the declarations the compiler
  hooks into, instead of the compiler finding them by path.

== The simulator interface
#status("planned")

A stable scheduler interface, shaped like the VPI that existing tools speak,
opens the native simulator to external drivers. The first target is cocotb,
so Python testbenches can drive siox designs; the same interface serves
co-simulation and, later, the mixed-signal coordination of Phase 2.
