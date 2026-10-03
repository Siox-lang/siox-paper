#import "../style.typ": *

= Types

== The kernel
#status("done")

The compiler knows only a handful of types: `integer` (a 64-bit signed
word for arithmetic and parameters), `real` (IEEE binary64), `Char` (a Unicode
code point, deliberately not a number), `Bool` (`true`/`false`, the type of
conditions) and `string`, an array of `Char`. Everything else, including the
logic values and the numeric vectors hardware is written in, is declared in
the standard library.

== Logic values
#status("done")

The digital scalars form a chain of newtypes, each adding values or
behaviour:

#table(
  columns: (auto, auto, 1fr),
  table.header([*Type*], [*Values*], [*Meaning*]),
  table.hline(stroke: 0.5pt),
  [`Bit`], [`'0' '1'`], [Two-state, like VHDL `bit`. Internal signals and clocks.],
  [`ULogic`], [`'U' 'X' '0' '1' 'Z' 'W' 'L' 'H' '-'`], [IEEE `std_ulogic`: nine values, unresolved.],
  [`Logic`], [as `ULogic`], [IEEE `std_logic`: the same values, plus resolution, so tristate buses work.],
)

The truth tables for `and`, `or`, `not`, `xor`, `nand`, `nor` and `xnor`, and
the resolution function, are the IEEE 1076-2019 tables, written in the
standard library as operator implementations and checked row for row against
a reference simulator.

A vector of logic carries its metavalues: the simulator keeps, beside each
value plane, a companion plane for the elements that are not plain `'0'`/`'1'`,
only where such values can actually occur. `'U'` and `'X'` propagate through
logic, arithmetic and comparisons as the standard says, and waveforms show
them as `x` and `z`.

== Numeric vectors
#status("done")

`unsigned[N]` and `signed[N]` are vectors of `Logic` with a numeric meaning,
like `ieee.numeric_std`. They are library types: nothing in the compiler
tracks signedness, and `signed` differs from `unsigned` only by its operator
implementations (a sign-aware `Ord`, an arithmetic `>>`, a signed `/`).

- *Widths are strict.* An assignment or connection must match widths exactly.
  Arithmetic does not widen: `unsigned[8] + unsigned[8]` is `unsigned[8]` and
  wraps.
- *Conversions are explicit.* `unsigned[16](a)` zero-extends or truncates;
  sign extension is the library function `sext`, so a signed value widens as
  `signed[16](sext(s))`. A constant that does not fit its target is a compile
  error.
- *Arbitrary width.* Vectors are not limited to a machine word: storage,
  shifts (`unsigned[128](1) << 64`), metavalues and printing keep every bit
  of values wider than 64.
- *Literals.* `x"AB_CD"` (hex), `o"17"` (octal) and `"1X10"` (one logic value
  per character) are bit strings; their width is their digit count.

== Ranged integers
#status("done")

`integer<lo..hi>` is an integer restricted to a range, stored in the fewest
bits that hold it (two's complement when the range goes below zero). The
standard library names the familiar ones: `Byte = integer<0..255>`,
`Natural`, `Positive`, `Short`, `Int`, `Long`. A constant out of range is a
compile error; a value that leaves its range while simulating is reported
with the signal's path.

== Aggregates
#status("done")

- *Structs* are named fields, with positional, named and spread-update
  literals: `{ ..base, .valid = '1' }`.
- *Enums* are finite states. Their variants can be names (`Idle`, `Busy`) or
  characters, which is how `Bit` and `Logic` themselves are declared.
- *Arrays* have declared, directional index ranges (`Logic[7..0]`,
  `unsigned[8][0..15]`); indexing and slicing (`data[7..0]`, `data[..4]`) use
  the declared indices. The system attributes `'length`, `'left`, `'right`,
  `'high`, `'low`, `'ascending` and `'range` read an array's shape at
  elaboration time.

== Newtypes and aliases
#status("done")

`type Word = unsigned[32];` is a transparent alias: `Word` *is*
`unsigned[32]`. A new nominal type wraps an existing representation:
`struct Meter(real);` and `enum Logic(ULogic);` share a representation but are
distinct types, with the conversion between them generated automatically.
Derivation never adds members or inherits behaviour; bigger types are built by
composition.

== Every value starts defined
#status("done")

A signal without an initializer starts at its type's default value, given by
the `New` trait: `'U'` for `Logic`, `'0'` for `Bit`, zero for numbers, the
first variant for an enum. siox signals are always initialized; they may be
undriven, and the compiler warns when they are.
