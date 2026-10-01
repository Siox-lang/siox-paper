#import "../style.typ": *

= Program structure

== Modules and imports
#status("done")

A file is one module, named on its first line. Imports follow Rust, with one
change: an import is renamed with `=`, not `as`.

```siox
module bus::uart;

use std::logic::Logic;                 // one item
use std::bits::{unsigned, sext};       // several from one module
use Master = bus::axi::Master;         // renamed import (Rust: `as Master`)
pub use std::logic::{Bit, Logic};      // re-export

type Word = unsigned[32];              // transparent type alias
pub type Byte = integer<0..255>;
```

A `use` of a project module loads the file it names (`use bus::spi::Master;`
reads `bus/spi.siox`), and `std::` paths come from the standard library.
Fully qualified paths work everywhere without an import. A small prelude is
in scope in every module, so `Bit`, `Logic`, `unsigned`, `signed`, `string`,
`time` and the directives need no import.

Items are private to their module by default and exported with `pub`. Visibility
follows the owning container, as in Rust: a struct field or an inherent method
is private unless marked `pub`, and nothing can be more visible than its owner.

The remaining Rust import forms are designed and come next
#status("proposal"): nested groups and `self` in a group, glob imports
(`use bus::axi::*;`), `self::` and `super::` paths, imports inside blocks,
generic type aliases, and separate namespaces for types, values and macros.

== Entities and implementations
#status("done")

An entity is a hardware component's interface: its ports, and nothing else.
Its behaviour lives in an implementation, as a Rust type's methods live in an
`impl`.

```siox
entity Uart<BAUD: integer> {
    clk: Bit in,
    rx: Bit in,
    tx: Bit out,
    data: unsigned[8] out,
    valid: Bit out,
}

impl<BAUD: integer> Uart<BAUD> {
    let shift: unsigned[8] = 0;
    let count: integer<0..15> = 0;
    // processes, concurrent assignments, instances, functions ...
}
```

A port is written like a struct field, `name: Type`, followed by its
direction: `in`, `out` or `inout`. A direction is a permission: an
implementation may write its `out` ports and only read its `in` ports.
Writing an input is an error. `inout` ports are tristate nets whose parallel
drivers resolve.

State, behaviour and sub-instances all live in the implementation. An entity
body that holds anything but ports is an error: the interface stays readable
at a glance, and an implementation can be split across several `impl` blocks.

== Instances and connections
#status("done")

An instance is declared with `let`, and its ports are connected the way a
struct literal is written: by name, or by position.

```siox
let rx_uart: Uart<BAUD = 115200> = { .clk = clk, .rx = pin, .tx = tx, .data = d, .valid = v };
let tx_uart: Uart<BAUD = 115200> = { clk, rx2, tx2, d2, v2 };   // by port order
```

Ports can also be wired after the declaration, through the instance:

```siox
let dut: Counter<W = 8>;
dut.clk = clk;          // drive an input
count = dut.count;      // read an output
```

A missing required connection, or a connection to a port the entity does not
have, is an error naming the port; an output connected to two producers is
the conflicting-driver error, pointing at both connection sites.

== Buses and views
#status("done")

A struct is layout without direction. A *view* gives a struct a protocol role,
with a direction for every field, so one struct serves both ends of a bus:

```siox
struct Stream<T> { valid: Bit, ready: Bit, data: T }

view Source<T> for Stream<T> { valid out, ready in, data out }
view Sink<T>   for Stream<T> { valid in,  ready out, data in }

entity Producer { bus: Stream<unsigned[32]> Source }
entity Consumer { bus: Stream<unsigned[32]> Sink }

impl Top {
    let wire: Stream<unsigned[32]>;
    let p: Producer = { .bus = wire };
    let c: Consumer = { .bus = wire };
}
```

The applied type writes the backing struct first and the view second, where a
port's direction goes. Views overload by backing struct, so `Source` can be
declared for many protocols without a name clash, and methods and trait
implementations can be attached to an applied view (`impl Stream<T> Source`).

== Parameters and generation
#status("done")

Entities, structs, traits and functions take generic parameters, resolved at
elaboration: `entity Counter<W: integer>`, instantiated as `Counter<W = 8>`.
Parameters can size ports and state, select types, and drive generation.

A `for` loop or an `if` with a constant condition at the top level of an
implementation is *structure*: it is unrolled or selected once, at
elaboration.

```siox
impl Chain<N: integer> {
    let w: unsigned[8][0..N];

    stages: for k in 0..(N - 1) {
        let s: Stage = { .i = w[k], .o = w[k + 1] };
    }

    tap: if DEBUG == 1 {
        let probe: Probe = { .i = w[N] };
    } else {
        let probe: Stub = { .i = w[N] };
    }
}
```

Ranges are inclusive and directional, like a declared index range: `0..2` is
0, 1, 2 and `2..0` counts down. A labelled `for` becomes a scope in the
elaborated hierarchy, with one child per iteration keyed by the loop value in
square brackets (`chain.stages[0].s`); a labelled `if` is one scope filled by
whichever branch is taken (`chain.tap.probe`). The same path appears in the
instance tree, the IR, the waveform and the debugger. Labels are optional;
an unlabelled loop names its instances with their indices (`s_0`, `s_1`).

An entity may only be instantiated where structure is built: at the top of an
implementation or inside a structural `for`/`if`. Instantiating inside a
process, a `match` arm or a function is an error, because control flow that
runs while simulating cannot create hardware.
