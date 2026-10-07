#import "../style.typ": *

= Behaviour

== Wires and processes
#status("done")

An implementation describes behaviour two ways.

- A *concurrent assignment* at the top level is a wire: `y = a and b;` means
  `y` always equals `a and b`. Each one is its own driver.
- A *process* is a block of ordered statements. Processes run concurrently
  with each other and with every wire; the statements inside one process run
  in source order.

```siox
impl Register {
    update: process {
        if clk.rising() {
            q = d;
        }
    }

    changed = q != q'old;          // a wire beside the process
}
```

The compiler infers what a process is sensitive to; there is no VHDL-style
sensitivity list. A process may carry a VHDL-style label (`update:`), and so
may any assignment (`sum: y = a + b;`). Labels are never required and never
change behaviour: they name things in diagnostics, the IR and the debugger.

== One assignment operator
#status("done")

There is one assignment operator, `=`, and its meaning comes from context: an
initializer on a `let`, a wire at the top level, an update inside a process,
or a port connection.

Inside an event-controlled block, assignments to signals take effect at the
end of the step (next-state semantics), so `a = b; b = a;` on a clock edge
swaps the two values. Local `let` bindings inside a process update
immediately.

Within one process, a later assignment overrides an earlier one under its
condition, which allows the default-then-override style:

```siox
process {
    y = b;                 // default
    if sel { y = a; }      // override
}

z = if x > 200 { 200 } else if x < 10 { 10 } else { x };   // the same select as an expression
```

There is no `?:` operator; `if` is an expression, as in Rust. Source order
never gives priority *between* processes or wires: two independent drivers of
one signal are either folded by the signal type's resolution, or an error.

== Events, clocks and reset
#status("done")

Every digital signal has two system attributes: `'event` (it changed in this
delta cycle) and `'old` (its value before the change). Clock edges are built
from them, in the standard library, as ordinary trait methods:

```siox
pub trait ClockLike {
    fn rising(self) -> Bool;
    fn falling(self) -> Bool;
    fn edge(self) -> Bool;
}
```

`clk.rising()` is defined in the standard library from `clk'event` and
`clk'old`, the way VHDL's `rising_edge` is. There is no special clock type: any single-bit signal is a clock when an edge is taken on it, and a user
type becomes a clock by implementing `ClockLike`.

Reset is ordinary logic. A synchronous reset is a test inside the clocked
branch; an asynchronous reset is a test before it:

```siox
process {
    if rst == '1' { q = 0; }
    else if clk.rising() { q = d; }
}
```

== Conditions
#status("done")

A condition must be a type that says how to be true: it implements the
`Boolean` trait. `Bool` and `Bit` do. `Logic` deliberately does not, because a
`Logic` can be `'X'` or `'Z'`: write `rst == '1'`, never `if rst`. A user type
(a state enum, say) becomes usable as a condition by implementing `Boolean`.

== Pattern matching
#status("done")

`match` works on enums, characters, numbers, ranges and bit patterns, with or
patterns and a wildcard, as a statement or as an expression. A match that
does not cover every value, or has an arm that can never be reached, is a
lint.

```siox
match state {
    State::Idle => { if start { state = State::Busy; } }
    State::Busy | State::Wait => { if done { state = State::Idle; } }
}
```

== Multiple drivers and resolution
#status("done")

A signal driven from two places (two processes, two wires, two instance
outputs) is only legal if its type implements `Resolve`, a commutative fold of
the drivers' values. `Logic` implements the IEEE `resolved` function, so a
tristate bus of `Logic` works; `Bit` and `ULogic` do not, so two drivers of
either are an error that names each source.

```siox
impl Shared {
    line = a;     // two drivers of one Logic line,
    line = b;     // folded by Logic's Resolve implementation
}
```

#diagram(caption: [Two drivers of one `Logic` line, from the simulator's VCD.
A released driver (`'Z'`) yields to the other; when both drive, `'1'`
against `'0'` resolves to the unknown `'X'`, and the line floats at `'Z'`
when neither does.])[
  #wave(
    cells: 14,
    axis: ((0, [0]), (2, [10 ns]), (4, [20 ns]), (6, [30 ns]), (8, [40 ns]), (10, [50 ns]), (12, [60 ns])),
    ([a], "z.1.z...1.z..."),
    ([b], "z.....0.....z."),
    ([line], "z.1.z.0.x.0.z."),
  )
] <fig-resolve>

== Time
#status("done")

Simulation time is a value: `time` is a nominal integer of femtoseconds, with
unit suffixes (`10ns`, `2us`), and `frequency` a nominal real (`100MHz`).

- `await 10ns;` advances time, `await clk.rising();` waits for an edge, and
  `await cond;` waits until a condition holds. `await` is for testbenches.
- `x = v after 5ns;` schedules a delayed write with VHDL's inertial
  semantics. It is testbench stimulus, not hardware; in a design it is an
  error.

The scheduler runs delta cycles (@fig-delta). Within one simulation time,
wires are first settled to a fixed point; then every clocked block whose
trigger changed runs, reading the values from before the edge; then all their
writes are committed together. If a commit changed anything, another delta
cycle follows; when nothing changes, time advances to the next scheduled
event.

#diagram(caption: [One delta cycle, repeated until a commit changes nothing;
only then does time advance.])[
  #grid(
    columns: 3,
    align: center + horizon,
    column-gutter: 6pt,
    row-gutter: 5pt,
    step(colour: c-run)[settle the wires\ to a fixed point], arrow("right"),
    step(colour: c-run)[run the clocked blocks\ whose trigger changed],
    arrow("up", label: [yes: another delta]), [], arrow("down"),
    step(colour: c-muted)[did the commit\ change anything?], arrow("left"),
    step(colour: c-run)[commit all their\ writes together],
    arrow("down", label: [no]), [], [],
    step(colour: c-run)[advance time to\ the next event], [], [],
  )
] <fig-delta>

Because wires settle inside each delta, a wire never lags the register it
reads. @fig-zoom stretches the instant of one clock edge of the counter in
@fig-counter: the edge is delta 0, and the register `value` and the wire
`count = value` both change in delta 1. (A VHDL concurrent assignment would
follow one delta later.)

#diagram(caption: [The clock edge at 15 ns in `Counter`, one column per delta
cycle. The simulator confirms it: a process woken by `value` changing already
sees the new `count`.])[
  #wave(
    cells: 8,
    marks: (2, 4, 6),
    axis: ((0, [before]), (2, [15 ns, δ0]), (4, [δ1]), (6, [after])),
    ([clk], "0.1....."),
    ([value], "=...=...", ("0", "1")),
    ([count], "=...=...", ("0", "1")),
  )
] <fig-zoom>
