#import "../style.typ": *

= Abstraction

== Traits and generic implementations
#status("done")

A trait is a compile-time contract: a set of functions a type must provide.
There are no vtables and no run-time dispatch; every call resolves when the
design is elaborated.

```siox
trait Source<T> {
    fn send(self, value: T);
    fn can_send(self) -> Bit;
}

impl<T> Source<T> for Stream<T> Source {
    fn send(self, value: T) {
        self.valid = '1';
        self.data = value;
    }
    fn can_send(self) -> Bit { return self.ready; }
}
```

The `self` parameters in these examples are today's syntax, and they are on
their way out: the owner has accepted implicit receivers (@receivers), so `fn`
will take its receiver implicitly and `static fn` will mark a function without
one, in traits and implementations alike.

Generic implementations are written with Rust's binder,
`impl<W: integer> Counter<W>`. Bounds restrict generic code to types that
provide what it uses, and a blanket implementation over arrays lifts an
element's behaviour to every array of it:

```siox
impl<T: Resolve> Resolve for T[] {
    fn resolve(self, rhs: T[]) -> T[] {
        let result: T[] = self;
        for i in self'range { result[i] = self[i].resolve(rhs[i]); }
        return result;
    }
}
```

== Operators
#status("done")

Operators are traits, as in Rust. Each standard operator has its own:
`Add`, `Sub`, `Mul`, `Div`, `Rem` (`%`, with the dividend's sign), `Shl`,
`Shr`, `And`, `Or`, `Not` and `Neg` (unary `-`), with a
method named after it. A type gets `+` by implementing `Add`, and the method
can also be called directly, `a.add(b)`:

```siox
impl Add<Complex, Complex> for Complex {
    fn add(self, rhs: Complex) -> Complex {
        return Complex { .re = self.re + rhs.re, .im = self.im + rhs.im };
    }
}
```

The traits double as bounds: a generic function over any type that can be
added says `T: Add<T, T>`.

Comparisons are two traits, as rustc's `PartialEq` and `PartialOrd`: `Eq`
gives `==` and `!=`, `Ord` gives `<`, `<=`, `>` and `>=`, and every method
returns `Bool`. A type with equality but no order implements `Eq` alone, and
an order may leave values unordered, as IEEE floating point does for NaN:

```siox
impl Eq<Version> for Version {
    fn eq(self, rhs: Version) -> Bool {
        return self.major == rhs.major and self.minor == rhs.minor;
    }
}

impl Ord<Version> for Version {
    fn lt(self, rhs: Version) -> Bool {
        return self.major < rhs.major or (self.major == rhs.major and self.minor < rhs.minor);
    }
    fn le(self, rhs: Version) -> Bool { return not rhs.lt(self); }
}
```

`abs`, `rem` and `mod` are functions, as in mathematics, and live in
`std::math` with `min`, `max` and the constants: `abs(x)`, `rem(a, m)` (the
dividend's sign) and `mod(a, m)` (the divisor's). They are generic, so one
`abs` serves `integer`, `signed`, the fixed formats and `float` alike.

*New* operators are `CustomOperator`, parameterized by their symbol. Any
symbol or word that is not reserved by the grammar can be an operator, and its
binding power is bound inside its implementation; the standard operators'
binding powers are the grammar's and cannot change:

```siox
impl CustomOperator<"xor", Logic, Logic> for Logic {
    attr precedence = 35;
    fn apply(self, rhs: Logic) -> Logic { … }
}
```

That is how `xor`, `nand`, `nor` and `xnor` exist: the standard library
declares them; the compiler does not know them. A custom operator's result is
the type its implementation declares, width, range and alias included, so
`(a clip b) xnor c` uses the declared `unsigned[3]` of `clip`, not the width of
its inputs.

An operator always dispatches on its operands' own types: a value is never
converted to fit an operator, so `u + arr` with an `unsigned[8]` and a
`Logic[8]` is an error whose help writes the conversion out.

== Literal prefixes and suffixes
#status("done")

`10ns`, `100MHz` and `5i` are ordinary literals with a suffix, and the suffix
is a trait implementation in source: `impl Suffix<"ns", integer> for time`
builds a `time` from the number. Bit-string prefixes work the same way through
`Prefix`. A library can add its own units and literal forms.

== Conversions: `From`, `Into` and `Default`
#status("done")

Three traits, three jobs:

#table(
  columns: (auto, auto, 1fr),
  table.header([*Trait*], [*Written*], [*Converts*]),
  table.hline(stroke: 0.5pt),
  [`From<S> for T`], [`T(x)`], [explicitly, at a conversion: `Complex(10)`, `Logic(u)`, `ufixed<8, 4>(x)`],
  [`Into<T> for S`], [nothing], [implicitly, where an `S` is stored as a `T`: a `let`, an assignment, an argument, a returned value, a struct-literal field],
  [`Default for T`], [`T::default()`], [nothing; it is the value a signal starts at],
)

A nominal vector family and a plain array of the same elements are different
types, joined only by `Into`. The standard library declares one both ways
between `Logic[]` and each family that is a newtype over it (`unsigned`,
`signed`, `ufixed`, `sfixed`, `float`), as a copy by position, so a logic
vector read from a port stores straight into an `unsigned[8]` or a
`ufixed<8, 4>`. Conversions that scale, round or saturate (between two fixed
formats, from `ufixed` to `unsigned`) stay an explicit `T(x)`. An `Into` is
declared by itself and needs no `From`; unlike Rust's, a `From` never implies
one, so every implicit conversion is one a library chose to allow. A composite
value converts to a vector or a number only through a `From` declared for it.

Types that are not built-in arrays can still be indexed by implementing
`Index` and `IndexAssign`.

== `#[derive]`
#status("done")

`#[derive(Eq, Ord)]` before a struct writes the comparison impls a user would
write by hand: `==` field by field, and `<`/`<=` lexicographically in declared
order, with `!=`, `>` and `>=` from the traits' defaults.

```siox
#[derive(Eq, Ord)]
struct Version { pub major: unsigned[4], pub minor: unsigned[4] }

if v1 < v2 { … }      // major first, then minor
```

Generic structs derive for every instance
(`impl<A, B> Eq<Pair<A, B>> for Pair<A, B>`), and a newtype compares as its
base. The impls belong to the
struct's own module, and an error inside one (a field whose type has no `==`)
is shown in the written-out impl, noted with the derive that wrote it.
`Resolve` does not derive, because a struct signal already resolves field by
field.

== Type attributes
#status("done")

An implementation may declare an attribute that every value of its type
answers, written in terms of `self`'s shape:

```siox
impl ufixed {
    pub attr integers: integer = self'high + 1;    // x'integers
    pub attr fractions: integer = 0 - self'low;    // x'fractions
}
```

A type attribute is a constant, as `x'high` is: it reads only shape (system
attributes, constants and functions over them), never the value. It is how the
library states the per-type facts VHDL leaves to `'high`/`'low` arithmetic, and
a format reads its target's through a qualified call, `ufixed<6, 2>::resize(x)`.

== Functions
#status("done")

In hardware a function is combinational logic: it is inlined where it is
called, and evaluated at compile time when its arguments are constants, so
`unsigned[clog2(DEPTH)]` works as a width. Generic functions bind their
parameters from their arguments, including integer ones:
`fn widen<W: integer>(x: unsigned[W]) -> unsigned[W + 4]` called with an
`unsigned[4]` is instantiated
with `W = 4`, as rustc monomorphizes.

Methods take `self`, and a type's *associated functions* are called through
its path (`Unicode::code(c)`, `Entity::helper(x)`, `T<args>::f(x)`). In a
testbench a function is an ordinary procedure: it may loop, `await`, return
early, write its caller's places through its parameters (`std::mem`'s `swap`
and `replace`), and recurse, each recursive call keeping its own frame.
`#[inline]` chooses whether the simulation expands calls or shares one native
copy; it never changes what a call means. C functions are available through
`extern "C"` blocks (@extern-c).
