#import "../style.typ": *

= Types

== The kernel
#status("done")

The compiler knows only a handful of types:

- `integer`, a signed 64-bit *mathematical* number for arithmetic and
  parameters. Leaving its range is an error, never a wrap: a division by zero
  or a `real` too large to convert is reported at the operation, as in VHDL.
- `natural`, its unsigned counterpart (0 to 2#super[64] - 1), with the same
  errors (`n - 1` at zero). It mixes with `integer` only through
  `natural(i)` and `integer(n)`, which check the range.
- `real`, IEEE binary64: `1.0 / 0.0` is infinity and `0.0 / 0.0` is NaN.
- `Char`, a Unicode code point, deliberately not a number: a character has a
  number only relative to an encoding table (`Unicode::code(c)`,
  `Ascii::char(65)`).
- `Bool` (`true`/`false`, the type of conditions) and `string`, an array of
  `Char`.

Everything else, including the logic values and the numeric vectors hardware
is written in, is declared in the standard library. Only `unsigned` and
`signed` wrap: they are hardware words, and their arithmetic is modular.

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
a reference simulator. How a logic value is encoded (its value bit, which
values are unknown, X01 normalization) is a standard-library contract,
`LogicEncoding`, evaluated by the compiler rather than duplicated in it.

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
  Arithmetic on one type does not widen: `unsigned[8] + unsigned[8]` is
  `unsigned[8]` and wraps.
- *Mixed numbers promote exactly.* Two numbers of different types meet at the
  higher rung of one ladder, `integer` → `unsigned`/`signed` →
  `ufixed`/`sfixed` → `float` → `real`, in a format that holds both:
  `unsigned[8] + signed[8]` is a `signed[9]`, `sfixed<8, 4> + unsigned[8]` an
  `sfixed<13, 4>`. Below `float` a promotion is only wiring. Storing the
  result still takes a conversion, where rounding and overflow are chosen.
- *Conversions.* `unsigned[16](a)` zero-extends or truncates, `signed[16](s)`
  extends the sign, and `resize(x, n)` takes the width as a value. A constant
  that does not fit its target is a compile error.
- *Arbitrary width.* Vectors are not limited to a machine word: storage,
  shifts (`unsigned[128](1) << 64`), metavalues and printing keep every bit
  of values wider than 64.
- *Literals.* `x"AB_CD"` (hex), `o"17"` (octal) and `"1X10"` (one logic value
  per character) are bit strings; their width is their digit count.
- *Bit methods*, after Rust's integer methods, work at any width in hardware
  and testbenches: `count_ones`, `leading_zeros`, `trailing_ones`,
  `reverse_bits`, `pow`, `saturating_add`, `rotate_left`, `is_power_of_two`
  and their relatives.

== Fixed and floating point
#status("done")

The formats are type parameters. `ufixed<8, 4>` and `sfixed<8, 4>` have eight
bits, four of them fraction, after VHDL's `fixed_pkg`; `float<32, 23>` is IEEE
binary32 (32 bits, 23 of them mantissa), after `float_pkg`. Arithmetic,
comparison and division keep the format; the format's own constructor converts
a number or another format, rounding and saturating (`ufixed<8, 4>(2.5)`,
`ufixed<12, 6>(x)`, `float<32, 23>(1.5)`). `float` adds square root and
conversions to and from the fixed formats. All of it is library source and runs
in hardware and testbenches alike.

== Ranged integers
#status("done")

`integer<lo..hi>` is an integer restricted to a range, stored in the fewest
bits that hold it (two's complement when the range goes below zero). The
standard library names the familiar ones: `Byte = integer<0..255>`,
`Short`, `Int`, `Long` and `Positive`. A constant out of range is a compile
error; a value that leaves its range while simulating is reported with the
signal's path and the declared domain.

== Aggregates
#status("done")

- *Structs* are named fields, with positional, named and spread-update
  literals: `{ ..base, .valid = '1' }`.
- *Enums* are finite states. Their variants can be names (`Idle`, `Busy`) or
  characters, which is how `Bit` and `Logic` themselves are declared.
- *Tuples* group values by position: `(unsigned[8], Bit)` is a type,
  `(q, '1')` a value, `t.0` a position, and `let (q: A, r: B) = divmod(x, 7);`
  declares both names. A tuple is the struct whose fields are its positions,
  so in hardware it is just wires, it flattens in waveforms as `t.0`, `t.1`,
  compares with `==`, prints as `('1', 9)`, and matches position by position.

== Arrays
#status("done")

Arrays have declared, directional index ranges (`Logic[7..0]` counts down,
`Bit[4]` is `Bit[0..3]`), and indexing and slicing use the declared indices:

```siox
let data: Logic[31..0];
let byte: Logic[7..0] = data[7..0];      // MSB first, as written
let top: Logic[7..0] = data[..24];       // an open end takes the declared bound
let table: unsigned[8][4] = [10, 20, 30, 40];
y = table[sel];                          // a runtime index: a lookup table
matrix[row][col] = v;                    // every dimension may be runtime
```

- *Nested arrays read inside-out* when declared: each `[N]` wraps the whole
  type to its left, so `unsigned[8][2][3]` is three rows of `unsigned[8][2]`,
  indexed outer first, `m[row][col][bit]`. The rule keeps types substitutable:
  with `type Row = unsigned[8][2];`, `Row[3]` is the same type.
- *Slices and elements are places:* `y[3..0] = a` and `y[i] = b` write part of
  a signal and keep the rest; partial ranges (`a[..1]`, `a[2..]`) work on
  ports, signals, locals and constant tables alike.
- *Unconstrained arrays* leave their range to the use, as VHDL's `range <>`:
  `string = Char[]`, and a port `s: string[5]` supplies the length. In a
  testbench, `T[]` is a run-time array: `read<integer[]>(path)` sizes it to a
  file, `xs.push(v)` appends, and `integer[][]` nests.
- The system attributes `'length`, `'left`, `'right`, `'high`, `'low` and
  `'ascending` read an array's shape as elaboration-time constants, and a
  named `range` constant (`const BYTE: range = 7..0;`) works in type and slice
  position.

== Newtypes and aliases
#status("done")

`type Word = unsigned[32];` is a transparent alias: `Word` *is*
`unsigned[32]`. A new nominal type wraps an existing representation:
`struct Meter(real);` and `enum Logic(ULogic);` share a representation but are
distinct types, with the conversion between them generated automatically.
Derivation never adds members or inherits behaviour; bigger types are built by
composition. A newtype over an array forwards the operators its base's
element provides, so a newtype over `unsigned[8]` keeps `+` and `==`.

== Every value starts defined
#status("done")

A signal without an initializer starts at its type's default value, given by
the `Default` trait: `'U'` for `Logic`, `'0'` for `Bit`, zero for numbers, the
first variant for an enum, and each field's default for a struct. `T::default()`
names it; a type that declares its own `default` (or an inherent `new`) runs
that body. siox signals are always initialized; they may be undriven, and the
compiler warns when they are.
