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
`Add`, `Sub`, `Mul`, `Div`, `Shl`, `Shr`, `And`, `Or`, `Not` and `Neg` (unary
`-`), with a
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
declares them; the compiler does not know them.

== Literal prefixes and suffixes
#status("done")

`10ns`, `100MHz` and `5i` are ordinary literals with a suffix, and the suffix
is a trait implementation in source: `impl Suffix<"ns", integer> for time`
builds a `time` from the number. Bit-string prefixes work the same way through
`Prefix`. A library can add its own units and literal forms.

== Conversions and indexing
#status("done")

`T(x)` converts explicitly. Kernel numeric conversions are built in and
width-driven; conversions between named types go through `impl From<Source>
for T`, so `Complex(10)` or `Logic(b)` are library code. Conversions never
happen implicitly. Types that are not built-in arrays can still be indexed by
implementing `Index` and `IndexAssign`.

== Functions
#status("done")

A function is a pure expression: it is inlined where it is called, in
hardware as combinational logic, and evaluated at compile time when its
arguments are constants, so `unsigned[clog2(DEPTH)]` works as a width.
Methods take `self`, and a type's *associated functions* are called through
its path (`Unicode::code(c)`, `Entity::helper(x)`). C functions are available
through `extern "C"` blocks (@extern-c).
