#import "../style.typ": *

= Reference

== Keywords

#table(
  columns: (auto, 1fr),
  table.hline(stroke: 0.5pt),
  [Items], [`module` `use` `type` `pub` `extern` `entity` `impl` `struct` `view` `enum` `trait` `attr` `const` `let` `fn` `process`],
  [Control], [`if` `else` `match` `for` `in` `return`],
  [Directions], [`in` `out` `inout`],
  [Contextual], [`await` `after` `where` `self` `true` `false` `not` `_`],
  [Word operators], [`and` `or` `not`, and the standard library's `xor` `nand` `nor` `xnor`],
  [Removed], [`using` (now `use`/`type`), `wait` (now `await`); both are errors that name the replacement],
)

== System attributes

#table(
  columns: (auto, 1fr),
  table.hline(stroke: 0.5pt),
  [`x'event`], [`x` changed in this delta cycle],
  [`x'old`], [`x`'s value before the change],
  [`x'length`], [number of elements],
  [`x'left`, `x'right`], [the declared bounds, in written order],
  [`x'high`, `x'low`], [the larger and smaller bound],
  [`x'ascending`], [whether the declared range counts up],
  [`x'range`], [the declared range, for iteration: `for i in x'range`],
  [`x'name`], [a declared attribute: the bound value, or the default],
)

`'ddt` is reserved for Phase 2 and is an error today.

== Directives

#table(
  columns: (auto, 1fr),
  table.hline(stroke: 0.5pt),
  [`#[test]`], [compile this entity into the test executable],
  [`#[allow(lints)]`], [do not report these lints in the next item or statement],
  [`#[warn(lints)]`], [report them as warnings (the default)],
  [`#[deny(lints)]`], [report them as errors],
  [`#[forbid(lints)]`], [as `deny`, and nothing inside may lower it],
  [`#![level(lints)]`], [any lint level, for the whole module],
  [`#[pipeline(N)]`], [a pipelined function of depth `N` #status("proposal")],
)

== Lints

#table(
  columns: (auto, auto, 1fr),
  table.header([*Lint*], [*Code*], [*Reports*]),
  table.hline(stroke: 0.5pt),
  [`possible_latch`], [W-P002], [a signal assigned on some paths of a combinational process only],
  [`unused_signal`], [W-P003], [a signal nothing reads],
  [`unused_param`], [W-P004], [a parameter nothing uses],
  [`unused_import`], [W-P005], [an import nothing uses],
  [`unreachable_match_arm`], [W-P006], [a `match` arm earlier arms already cover],
  [`non_exhaustive_match`], [W-P007], [a `match` that misses values],
  [`suspicious_logic_compare`], [W-P008], [a comparison of logic values that is likely a mistake],
  [`suspicious_reset`], [W-P009], [a reset pattern that is likely a mistake],
  [`combinational_loop`], [W-P010], [a signal that feeds itself with no register in the path],
  [`undriven_output`], [W-P011], [an output or signal nothing drives],
  [`unconnected_input`], [W-P012], [an instance input left unconnected],
  [`dead_assignment`], [W-P014], [an assignment a later one always overrides],
  [`unimplemented_attr`], [W-P015], [an attribute no tool reads yet],
  [`incomplete_struct_literal`], [W-P016], [a struct literal that leaves fields at their defaults],
  [`unknown_lints`], [W-P017], [a lint name that does not exist],
  [`warnings`], [—], [every lint at once],
)

== Glossary

/ Delta cycle: One step of simulation within a single instant: every process
  whose inputs changed runs, their writes are applied together, and the step
  repeats until nothing changes.
/ Driver: A source of a signal's value: a wire, a process that assigns it, or
  an instance output connected to it.
/ Elaboration: Turning parameterized entities into a concrete tree of
  instances, with generation unrolled and parameters substituted.
/ Entity: A hardware component's interface: its ports.
/ Metavalue: A logic value other than plain `'0'`/`'1'`, such as `'U'`, `'X'`
  or `'Z'`.
/ Process: A block of ordered statements that runs concurrently with
  everything else.
/ Resolution: Folding the values of several drivers of one signal into one,
  defined by the signal type's `Resolve` implementation.
/ View: A directional role over a struct, giving each field a direction, so
  one struct serves both ends of a bus.

== Further reading

- The siox compiler and its documentation, including the language
  specification and the proposals: #link("https://github.com/Siox-lang/sioxc")
- The siox test corpus: #link("https://github.com/Siox-lang/siox-tests")
- IEEE 1076-2019, the VHDL standard, for the nine-value logic system.
- Spade, an expression-based HDL with pipelines: #link("https://spade-lang.org/")
- The Rust Reference and the rustc development guide, for the conventions
  siox follows in its structure and its compiler.
