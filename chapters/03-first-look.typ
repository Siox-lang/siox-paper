#import "../style.typ": *

= A first look

An eight-bit counter with a testbench:

```siox
module counter;

entity Counter {
    clk: Bit in,
    rst: Logic in,
    count: unsigned[8] out,
}

impl Counter {
    let value: unsigned[8] = 0;

    update: process {
        if clk.rising() {            // runs only on a rising clock edge
            if rst == '1' { value = 0; }
            else { value = value + 1; }
        }
    }

    count = value;                   // a wire: always equal to `value`
}

#[test]
entity CounterTest {}

impl CounterTest {
    let clk: Bit = '0';
    let rst: Logic = '1';
    let count: unsigned[8];
    let dut: Counter = { .clk = clk, .rst = rst, .count = count };

    clock: process {
        clk = not clk after 5ns;     // free-running clock, 10 ns period
    }

    stimulus: process {
        await 10ns;                  // hold reset for one edge
        rst = '0';
        for i in 0..9 { await clk.rising(); }
        assert!(count == 10, "counter should reach 10");
    }
}
```

The `entity` declares the interface: three ports, each a name, a type and a
direction. The `impl` gives the behaviour. Two kinds of logic sit side by
side: a concurrent assignment (`count = value;`) is a wire that always equals
its expression, and a process is ordered behaviour, here clocked. `update:` is
an optional VHDL-style label that names the process in diagnostics and tools.

The testbench is an entity too, marked with the `#[test]` directive. It
instantiates the counter the way a struct literal is written, drives a clock
with a delayed self-assignment, and steps through time with `await`.

```text
$ sioxc --test counter.siox -o counter-tests
$ ./counter-tests -o counter.vcd

running 1 test
test counter::CounterTest ... ok

test result: ok. 1 passed; 0 failed; 0 filtered out
```

`sioxc` compiles; the executable it produces runs the tests and writes the
waveform. The same separation as `rustc --test`: the compiler never runs what
it builds.
