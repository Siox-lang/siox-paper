#import "../style.typ": *

= Metadata and directives

siox separates two things other HDLs mix: *metadata*, which only tools read,
and *directives*, which change what the compiler does.

#table(
  columns: (auto, auto, 1fr),
  table.header([], [*Spelling*], [*Removing it changes*]),
  table.hline(stroke: 0.5pt),
  [metadata], [`attr keep for probe = true;`], [only what a downstream tool sees],
  [directive], [`#[test]`, `#[allow(...)]`], [what the compiler emits, accepts, or reports],
)

== Declared attributes
#status("done")

An attribute is declared once, with a type, the targets it may apply to, and
a default. It is then bound from outside the declaration it describes, and
read back with the tick:

```siox
pub attr external_clock: Bool for Pll = false;   // declaration
pub attr speed: integer for entity, let = 1;

impl Top {
    attr external_clock for p = true;           // binds the instance `p`
    attr speed = 3;                             // binds the entity `Top`

    let p: Pll = { .clk = clk, .locked = l };

    count = p'speed;    // the binding on p, else Pll's binding, else the default
}
```

Because every attribute has a default, a read always has a value. Bindings
are compile-time constants, so a read costs nothing in the circuit. Binding
an attribute twice on one declaration is an error; a binding never silently
overrides another. Metadata bound on an instance appears on it in the
elaborated instance tree (`p: Pll [external_clock = true]`), for netlist and
constraint tools to export.

== Directives
#status("done")

`#[...]` is reserved for directives. The compiler implements them, and like
rustc's built-in attributes they are declared in the standard library and
reach every module through the prelude, so they resolve like any other name.
`#[test]` is recognised by its declaration, not its spelling: an attribute
named `test` declared in another module is ordinary metadata.

- `#[test]` compiles an entity into the test executable.
- `#[allow(lint, …)]`, `#[warn]`, `#[deny]` and `#[forbid]` set lint levels.
- `#[pipeline(N)]` will make a function a pipeline (@pipelines)
  #status("proposal").

Metadata written as `#[...]` is an error whose help gives the `attr` binding
that replaces it.

== Lints <lints>
#status("done")

Every warning is a *lint* with a snake_case name, as in rustc:
`possible_latch`, `unused_signal`, `undriven_output`, `combinational_loop`,
`dead_assignment`, `non_exhaustive_match`, `incomplete_struct_literal`, and
the others. A level is set for the item or statement a directive precedes, for
a whole module with `#![...]`, or for everything from the command line with
`-A`, `-W`, `-D` and `-F`:

```siox
module design;
#![deny(warnings)]                    // every warning in this module fails the build

impl Pipeline {
    #[allow(undriven_output)]         // a probe kept for the waveform
    let probe: unsigned[8];
}
```

The innermost level wins; `forbid` cannot be lowered by anything inside it.
A denied lint is a real error, and says which directive or flag made it one.
