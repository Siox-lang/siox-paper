#import "../style.typ": *

= Verification

== Testbenches are entities
#status("done")

A testbench is an entity marked `#[test]`. It has no ports; it instantiates
the design under test, drives it from processes, and checks it. Testbench
processes may do what hardware cannot: wait for time to pass, write files,
draw random numbers, print.

```siox
#[test]
entity AdderTest {}

impl AdderTest {
    let a: unsigned[8];
    let b: unsigned[8];
    let sum: unsigned[8];
    let dut: Adder = { .a = a, .b = b, .sum = sum };

    stimulus: process {
        seed(42);
        for i in 1..100 {
            a = unsigned[8](randint(0, 255));
            b = unsigned[8](randint(0, 255));
            await 1ns;
            assert!(sum == a + b, "the adder wraps like unsigned[8]");
        }
        print!("checked {} random additions", 100);
    }
}
```

A testbench may have several processes, each waiting on time or on signals
by itself; the scheduler interleaves them by simulation time and delta cycle,
so a monitor and a stimulus process run side by side, and none runs to
completion before the others start. Here the counter of the first example
gets a stimulus that resets it twice and a monitor that reports every edge:

```siox
impl CounterTest {
    // clk, rst, count and dut as in the first example

    clock: process {
        clk = not clk after 5ns;            // runs each time clk changes
    }

    stimulus: process {
        await 10ns; rst = '0';              // release reset
        await 30ns; rst = '1';              // reset again for one edge
        await 10ns; rst = '0';
        await 20ns;
    }

    monitor: process {
        for i in 0..7 {
            await clk.rising();
            print!("count = {}", count);    // after this edge has settled
        }
    }
}
```

@fig-interleave shows the run: the signals from its VCD, and beneath them
when each process ran. Every process starts at 0. The clock process runs at
each change of `clk`; the stimulus runs only when its `await 10ns` or
`await 30ns` expires; the monitor runs at each rising edge, and an `await` in
a testbench resumes only after the edge's consequences have settled, so it
prints the new count (0, 1, 2, 3, then 0 after the second reset).

#diagram(caption: [`CounterTest` with three processes, simulated. The upper
rows are the VCD; each lower row marks the moments a process ran, between
which it was suspended in an `await`. The monitor's marks carry the count it
printed. All three share one host thread; at a shared time they run in a
fixed order, so a run always reproduces.])[
  #wave(
    cells: 32,
    marks: (2, 6, 10, 14, 18, 22, 26, 30),
    axis: ((0, [0]), (4, [10 ns]), (8, [20 ns]), (12, [30 ns]), (16, [40 ns]), (20, [50 ns]), (24, [60 ns]), (28, [70 ns])),
    ([clk], "0.1.0.1.0.1.0.1.0.1.0.1.0.1.0.1."),
    ([rst], "1...0...........1...0..........."),
    ([count], "=.....=...=...=...=...=...=...=.", ("0", "1", "2", "3", "0", "1", "2", "3")),
    ([clock], "!_!_!_!_!_!_!_!_!_!_!_!_!_!_!_!_", (), c-run),
    ([stimulus], "!___!___________!___!_______!___", (), c-back),
    ([monitor], "!_!___!___!___!___!___!___!___!_", ("", "0", "1", "2", "3", "0", "1", "2", "3"), c-ir),
  )
] <fig-interleave>

Several testbenches may live in one file. Each is named by its qualified path
(`adder::AdderTest`) and runs independently.

== The test executable
#status("done")

`sioxc --test file.siox -o tests` compiles every `#[test]` entity in the file
into one native executable, as `rustc --test` does. The compiler never runs
it. The executable:

- runs every test, or those whose name matches a filter
  (`./tests adder::AdderTest`);
- reports each test as passed or failed, with the source location of a failed
  assertion, and counts warnings;
- writes waveforms when asked: `./tests -o run.vcd` (text VCD) or
  `./tests -o run.fst` (compressed FST), or both in one run. Several tests
  share one monotonic timeline.

== Checking and reporting
#status("done")

- `assert!(cond, "message")` fails the test when `cond` is false.
- `warn!(cond, "message")` reports and counts, and the test still passes.
- `print!("x = {}", x)` formats a line. Enum and logic values print
  symbolically (`Idle`, `'Z'`), characters and strings as text, and numbers in
  full, however wide. Placeholders take Rust's specs: `{:.3}` rounds to three
  decimals, `{:.2e}` is scientific, `{:#x}` hexadecimal, `{:>8}` pads and
  aligns.
- Structs print as `Packet { kind: Data, len: 12 }`, arrays as `[1, 2, 3]`
  and logic vectors as `10XZ`. A type prints its own way by implementing
  `Display`, whose `fmt` body uses `write!`; `float`, the fixed-point formats
  and `Complex` do.
- `stop()` ends the test as passed so far; `finish()` ends the simulation.
- A value that leaves a ranged type, or a file read that fails, is reported
  with the signal's path or the source location.

The macros capture their source location, which is why they are macros: a
failure names the line of the call, even when the call is inside another
macro. `error!("message")` fails unconditionally, like Rust's `panic!`. All
four are declared in `core` (@macros).

== Stimulus services
#status("done")

- *Randomness* is deterministic: `rand()`, `randint(lo, hi)`, `uniform()` and
  `seed(n)` come from one generator with a fixed default seed, so a run always
  reproduces.
- *Files*: `read<string>(path)` decodes UTF-8 text, `read<integer>(path)` and
  `read<unsigned[16]>(path)` read binary fixtures, and `exists(path)` probes
  for one. In hardware an initializer read happens at compile time, baking a
  ROM image; in a testbench it happens when the test runs.

== Waveforms and debugging
#status("done")

Waveforms record every signal with its hierarchy path: instances and labelled
generate scopes nest (`top.stages[0].s.o`), enums appear by name, `Logic`
appears with `x` and `z`, and structs and arrays flatten to one trace per
field or element. The files open in GTKWave or Surfer.
