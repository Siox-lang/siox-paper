# Testing

siox testbenches, how to run them, and how the compiler itself is tested.

## `#[test]` entities are testbenches

A testbench is an entity marked `#[test]`. It instantiates a design-under-test,
drives its inputs over time, and asserts on its outputs — the HDL equivalent of
a `#[test]` function:

```siox
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

Testbench processes are concurrent, while statements inside one process run in
order. `await` advances simulation time (see
[simulation.md](simulation.md)), and a process-local `let` is a mutable local
with ordinary sequential assignment. The fixed native scheduler runs several
independently suspending foreground processes and background clocks. Each
process yields at `await` or a settling boundary; its own continuation resumes
when ready. These processes cooperate on one host thread, not OS threads.
Test processes receive stable process/block/local and
value IDs plus validated branch, match, loop, suspension, and termination CFGs
inside `Design::process_ir`; hardware processes and test stimulus execute from
those CFGs through the same LLVM/runtime path. There is no second test-only
program, generated source translation, or runner.
Method calls on the DUT or on struct-typed locals work in
stimulus, so a testbench can drive a design through a method result. Strings
retain their array semantics here: locals can be
initialized or assigned from another same-length string, and equality compares
their characters (including the zero-character empty-string case).
Unconnected `Char` locals, string elements, and `Char` fields retain Unicode
character context for initialization, assignment, and comparison just like
DUT-connected character signals.
Unconnected `real` locals and fields likewise use floating-point semantics for
arithmetic, comparisons, conditionals, negation, and formatted output; their
native storage remains the same f64 bit representation used by real signals.
Calls to declared `extern "C"` functions are also valid in native testbench
expressions; parameter and return conversion follows the declaration (`real`
crosses as C `double`, `integer` as the signed ABI word, and packed scalars as
an unsigned ABI word).
Native kernel-`integer` locals and loop counters retain signed comparison,
division, arithmetic-right-shift, and formatting semantics. Each `for` body has
its own value/type scope: a range binds an `integer`, collection iteration binds
the element type, nested shadowing restores the enclosing loop metadata, and
leaving the loop restores any same-named outer local.
The same signed behavior applies to module constants, function/method results,
struct fields, plain connected integers, and width-constrained integer signals;
constrained values are sign-extended from their stored width before use.
Named `real` constants and real-typed parameters/returns of ordinary functions
and methods retain that same representation while native code inlines them.
Struct-local numeric leaves use their declared width as well: fields wider
than one ABI word preserve every word, while a narrower field still wraps at
its own boundary.
Unconnected scalar/vector arrays are materialized one typed element at a time,
so literals, indexing, element mutation, and same-shaped array copies preserve
arbitrary-width elements too.
Materialization is recursive for nested arrays, arrays of structs, and arrays
of fixed-size strings; composite copies match scalar leaf paths rather than
collapsing an aggregate into one machine word.
Unconstrained string/array locals acquire the initializer's concrete native
storage shape, and later assignments must match it. Struct locals accept the
same named, positional, typed-positional, and spread-update forms during
reassignment as during initialization; every form writes the flattened fields
in declaration order. Recursive initialization retains nested struct literals,
whole-struct copies, nested spreads, arrays of structs, and fixed-size string
fields rather than defaulting their descendant leaves.
Explicit local ranges retain their declared logical indices and direction.
This applies to numeric vectors and arrays alike: indexing, iteration, string
literal initialization of logic arrays, and the `'left`, `'right`, `'high`,
`'low`, `'length`, and `'ascending` attributes all observe the declared range.
Named `range` constants can be used as local type indices, and signed bounds
remain addressable. Integer constants can likewise supply local widths; based
and `_`-separated literal spellings retain the same width and value through
analysis, elaboration, IR, and native test generation, including direct real
reassignment and comparison.

## Reporting

- `assert!(cond, "msg")` — fail the test if `cond` is false.
- `warn!(…)` / `print!(…)` — diagnostics and logging; enum and logic values
  render symbolically (`Idle`, `'Z'`), `Char` and string values render as
  Unicode, and arbitrary-width numeric values retain every decimal digit.
- `stop()` / `finish()` — end the run. They are ordinary functions, not
  macros: `stop()` halts the test, which passes so far, and `finish()` ends
  the simulation cleanly.

## Running

`sioxc --test` finds every `#[test]` entity and compiles a native test
executable. `sioxc` is only the compiler; run the executable to execute or
filter tests:

```console
$ sioxc --test counter.siox -o counter-tests
$ ./counter-tests
running 1 test
test counter::CounterTest ... ok

test result: ok. 1 passed; 0 failed
```

- **Filter by qualified name:** `./counter-tests counter::CounterTest` runs the
  matching subset. Partial names also work as filters.
- **Debugging:** `sioxc --test -g` emits direct LLVM DWARF with optimization
  disabled. Use GDB source-line breakpoints, `next`, and source variable names;
  see the debugger checks and inspection conventions below. Ordinary runtime
  failures still carry Siox source locations without `-g`.
- **Failures name their source.** A failing `assert!`, a ranged signal leaving
  its domain, and a failing `read<T>` all print `--> file:line:col` beside the
  message, followed by the source line and a caret, so a CI log points at the
  line without a debugger. An assertion names its own statement; a range
  violation names the *assignment* that left the domain, not the declaration
  that set it, falling back to the declaration only for a signal written by a
  driver the compiler synthesized (a port connection).
- **Waveforms:** `-o trace.fst` writes compressed FST; `-o trace.vcd` writes
  portable text. The path's extension picks the format, so FST is the default
  without naming it. `--output=<path>` and `-o<path>` are equivalent, and
  passing `-o` twice with one of each extension writes both.
  Either option may precede or follow the test filter, and both may be requested
  together with different paths; using the same path is rejected. They share
  the same 1 fs scheduler samples and place multiple tests consecutively on one
  monotonic timeline.
  A filter matching no tests leaves waveform paths untouched. A selected test
  with no observable signals can still write an empty VCD, but requesting FST
  fails before creating/truncating that FST path: libfst requires at least one
  variable. Tests with signals may produce valid FST at time zero without an
  `await`.
- **A directory:** corpus orchestration belongs to the build/test tooling, not
  the compiler. `scripts/test-corpus.sh` compiles and runs each `.siox` file.
- **Native binary:** `sioxc --test <file> -o <bin>` builds a standalone test
  executable that exits 0 on pass.

A file with no `#[test]` entity reports zero tests rather than erroring.

## Native debugger smoke test

GDB can debug the native runtime, or step Siox source and inspect named state
when compiled with `--debug`. The reproducible check uses the existing FIFO and
128-bit corpus designs in both ordinary and debug builds:

```bash
bash scripts/guarded-run.sh bash scripts/test-gdb.sh /home/max/siox-tests
```

It verifies timed-wait and process-entry breakpoints, scheduler backtraces,
instruction stepping, signal reads through the waveform metadata and
`sx_read_word`, and byte-identical VCD output versus normal execution. The wide
case checks both 64-bit words of a 128-bit carry, source breakpoints/stepping,
and named wide structs/arrays. Ordinary builds still omit source metadata.
This requires GDB with Python support and permission to launch a traced child;
it adds no DAP or editor integration. Waveform tables are not a stable
source-debugger API.

```bash
sioxc --std std --test --debug /home/max/siox-tests/fifo_test.siox -o fifo-tests
gdb ./fifo-tests
# (gdb) break fifo_test.siox:26
# (gdb) run
# (gdb) print FifoTest::d::count
# (gdb) next
```

DWARF namespaces follow elaborated instance paths: `FifoTest::d::head` names
internal FIFO state, while `FifoTest::dout` names persistent test storage.
Process locals use their lexical names; shadowed locals regain their outer
binding after the inner block exits, including across `await`. Select the Siox
caller frame (`up`) if stopped inside an unannotated native runtime helper.
Debug artifacts advertise the C++ debugger expression grammar because Siox has
no native debugger language integration; code generation remains direct LLVM.

Integers, reals, std/user enum discriminants, multiword vectors, structs and
fixed arrays retain their source types. Packed aggregates that cannot be read
faithfully as native bitfields use debug-only byte-aligned inspection buffers,
refreshed at Siox source boundaries. Do not write these buffers to mutate the
simulation or expect them to update while stopped inside runtime helpers.
Ascending arrays preserve their lower bound (`words[-1]`); descending arrays
are labelled records rather than silently reversed C++ arrays. GDB Python can
inspect their labels with `gdb.parse_and_eval('T::rows')['[3]']`. Flattened
hardware leaves containing brackets need quoted symbol names, for example
`print 'FifoTest::d::mem[0]'`.

Packed vectors retain their numeric view and additionally expose a read-only
`$logic` snapshot (`print T::bus$logic` or `print local_bus$logic`). Its elements
are the source enum variants, not raw metadata nibbles: X/Z, weak values and
user enum symbols come from elaborated type metadata. For structs and arrays
containing packed vectors, the companion preserves the recursive shape and
ordinary scalar fields. Apply the same ascending-array/descending-record
indexing conventions described above. These views refresh at source boundaries
alongside the other inspection buffers; they do not change simulation storage.
Expression-call formals and copied locals also expose `$logic` in their owning
frame. For example, GDB Python can read `gdb.selected_frame().read_var('value$logic')`.
These snapshots become available only when ordinary emission has produced both
planes, or proven the value metadata-free. Inspection never evaluates a missing
plane or repeats a source call. Unconsumed planes are optimized out, not shown
as known binary values; source branches may leave a companion unavailable even
when its numeric view exists. Partial hardware aggregate companions preserve
available scalar fields while pruned packed members remain optimized out.
Process frames and function breakpoints are instance-qualified, for example
`break T::stimulus`.

Procedures and value-returning functions expanded into CFGs retain source
inline frames and call sites. Use `up`/`down` to select the caller or callee;
equal-spelled locals remain distinct at repeated calls (even on one source
line), in nested calls and after `await`. Lexical shadowing stays within its
own call instance rather than merging scopes with identical definition spans.
`info args` shows formal parameters under their signature names (including
`self`). Captured place arguments retain their language aliasing: after a
callee writes through an argument, inspection reports its current value, not
an entry-time copy. Structs, indexed places, wide/real projections and runtime
strings use the same read-only inspection conventions as locals. Return types
are also retained in the source subroutine metadata.
Literal string arguments use that same `length`/`data`/`byte_length`/`utf8`
view, backed by immutable character/byte arrays rather than runtime handles.
Empty literals remain visible formal arguments: both lengths are zero and
both content pointers are null, even though the language value has no storage.

Expression-shaped calls in procedural processes retain distinct source
frames for repeated, same-line and nested calls. Shared Process functions retain source metadata directly on their existing
native body. Inline-only calls compile once per consumer format as a native
function: conditional consumers reuse that body instead of recursively
duplicating it. These are
direct LLVM functions over the same Process IR, not generated C or a separate
frontend pipeline. Their scalar/aggregate parameters and
local aliases use read-only debug views populated from values the program
already evaluates, not by reevaluating expressions. Debug-only return views
keep return-line breakpoints observable when LLVM combines nested arithmetic
even at `-O0`; ordinary builds introduce no simulation storage/copies for these
boundaries. Unselected expression calls must not acquire runtime source stops.
Pure function-body `if`/`match` branches retain lexical local scopes, including
nested shadowing. Return breakpoints follow the selected return expression,
even when both arms return the same existing argument. Debug-only control-flow
boundaries finish a local's inspection view before a later source statement can
stop; LLVM instruction scheduling must not expose an uninitialized snapshot.
Metadata-only arguments do not enter the native call ABI: only the callee's
executable source operands may be evaluated, even if an unused binding remains
retained elsewhere in the IR.
Native argument formats come from the common emitter's actual width, signedness
and layout requests, not from debugger inspection types. A shared argument may
need more than one native format; evaluating it at its minimum width before
widening would change signed/contextual arithmetic. Entry inspection reuses
those native inputs for formals and same-value aliases without reevaluation.
Expression string formals and aliases use the same borrowed or immutable
content views as CFG parameters. Returning a runtime string preserves its
handle; downstream length, indexing and literal comparisons retain runtime
semantics. CFG-hoisted host operations are labelled with the caller's call
site, not the callee's return line, so return breakpoints stop in its frame.

Hardware expression calls use this same native-frame emitter. Source
bindings retain declaration-owned inspection layouts separately from executable
operand formats, so negative integer locals, wide signed/unsigned formals and
real values have faithful debugger types without introducing simulation casts.
Each source hardware process keeps its own frame inside bounded shared helpers;
generated scheduler instructions use line-zero native locations rather than a
borrowed source statement. Clocked calls retain their owning event process.
Hardware conditional returns carry selected-arm source spans and lexical scopes.
Field-backed aggregate parameters and local aliases use LLVM fragments of
already-evaluated leaf values. Nested structs, ascending arrays with negative
labels, descending arrays and non-byte-aligned wide signed/unsigned members
retain their declared shape. Inspection storage rounds leaves to whole bytes,
not ABI words: an 81-bit member occupies 11 bytes. Pruned members are unavailable
(`gdb.Value.is_optimized_out`), even when neighboring members can be inspected;
metadata must not evaluate an unused foreign-call field to fill a debug view.
Fully retained pure hardware aggregate returns share one native
call and exact-layout SSA result across selected field consumers. Tests require one
source stop when both fields, only the first, or only the second are consumed,
and none when neither is selected. Whole two-integer returns are also checked
with actual GDB `finish`, rather than inferred from parameter/local inspection.
Inactive effectful fields retain the ordinary demand behavior; debugger
grouping must not evaluate them to construct a complete packed return.
Nested if/match return branches also require one selected stop per input,
exact return/caller lines and the correct shadowed local. A branch-private
local must have no visible symbol on the fallback path. Independent field
conditions on one source line and aliased aggregate locals retain native
results and one source frame. GDB `finish` checks both returned integer fields
for every branch/input in ordinary, nested/match, independent and alias cases.

Runtime-owned `string`/`Char[]` values expose a read-only view under their source
name: `text.length` counts Unicode code points, `text.data[i]` reads one code
point, `text.byte_length` counts UTF-8 bytes and `text.utf8[i]` reads a byte.
For example, `print *text.data@text.length` displays the entire character array.
Use the explicit byte length for embedded NULs; normal C-string printing stops
at the first NUL. Content pointers borrow runtime storage until test cleanup;
do not mutate either the view or its pointed-to content. Uninitialized/invalid
handles and views from inactive tests are empty, without raising runtime errors.
Snapshots refresh only at Siox source boundaries, as described above.
Literal/empty string return calls also retain source stops when a length
consumer folds the value, including nested argument calls. Tests require the
actual caller/assignment line, constant parameter/local views and correct
argument order. A shared return stops once for both/first-only/second-only
consumers and not at all when neither is selected. Direct folded lengths in
untaken branches must not create a stop. Formatted print/warning operands use
the same path; successful assertions and suppressed warnings do not execute
their formatted string calls. Empty zero-storage specializations return void;
GDB `finish` returns to the caller without adding a value to its history.
This is distinct from a runtime string handle whose content happens to be empty.

Wide source-call views are checked at 81 and 129 bits for signed/unsigned
parameters and copied locals, including inferred generic declarations. Their
sizes remain 11/17 bytes when a caller narrows to 8 bits or widens to 193 bits,
and a callee returning just the low byte still exposes the original parameter.
Ordinary and debug executables verify the returned values and waveform parity;
the low-byte return also passes native GDB `finish`.

On AMD64, **do not use GDB 18.1 `finish` on an arbitrary-width basic integer
return**: it can report a false zero at 81 bits and hit an internal assertion at
129 bits. `set print finish off` does not avoid the assertion. The upstream
[AMD64 classifier](https://gnu.googlesource.com/binutils-gdb/+/refs/heads/master/gdb/amd64-tdep.c)
assigns integer classes only to 1/2/4/8-byte basic types. To step out without
asking GDB to decode that return ABI, run this while stopped inside the callee:

```text
python gdb.execute('tbreak *%#x' % gdb.newest_frame().older().pc())
continue
```

This keeps the true source types and values; it does not establish automatic
wide return-value decoding. That debugger limitation and general native
return-ABI validation remain separate open work.

Remaining inspection work includes demand-preserving whole aggregate-return
boundaries for effectful/checked/nested-call and partially retained results,
further companion argument/return-plane transport audits, and debugger `finish`
return-ABI
checks for runtime/nonempty-literal string, wide basic scalar, small subword/
unaligned and mixed-layout/
partial aggregate results.
Formal-type audits also remain for hardware operators/suffixes/conversions
and constrained/generic signatures; the tested scalar function cases do not
prove every signature specialization.
Runtime-sized native values currently support Char[]
handles only; general dynamic arrays are a separate host-service extension,
not an already-supported representation missing debugger metadata. Debug mode
is deliberately unoptimized; it is not a simulation performance mode. The
same option applies to native objects and `--emit llvm-ir`.

`tests/debug_info.rs` verifies metadata/object output, native execution,
source/function breakpoints and steps, persistent/shadowed locals, loop indices,
3-bit signed and 65/81/127/129-bit signed/unsigned storage/ports/locals,
all nine std logic states across waits, recursive companion views, nonstandard
enums, real/wide packed structs, labelled arrays, dynamic Unicode/UTF-8 strings
(including empty/embedded-NUL values, updates and cleanup between two tests),
and runtime string locals through inlined length/index/equality expressions in default and
`bitpack` builds. A second regression checks repeated/same-line/nested CFG call
frames, call-site lines, shadowed locals and suspension for procedures and
value-returning functions, plus formal arguments, mutable/indexed aliases,
struct receivers, wide/real fields and Unicode/embedded-NUL string arguments.
The argument checks cover both runtime strings and literals, including empty
literals; ordinary/debug executables must agree on character-count attributes.
A third regression checks procedural expression calls, scalar/aggregate bindings, nested
return-line breakpoints and selected versus unselected calls, with ordinary/debug
native execution and byte-identical VCDs in both packing modes. It also checks
direct packed-element locals and function arguments: a logic element keeps its
source discriminant instead of being read as a physical one-bit array slice.
Expression string coverage includes runtime/literal/empty formals and aliases,
borrowed-handle returns and caller locations, Unicode/embedded-NUL contents,
length/index/equality semantics, plus aggregate integer/real/wide field values.
The backend's inline-call regression checks that differently selected
consumers emit one function body per width format, without merging formats.
Native symbol counts also require repeated shared branch/alias calls to use
one body; GDB checks their selected return lines and lexical shadowing. Narrow
integer actuals retain 64-bit declared formal/local inspection types without
changing their executable consumer formats.
A fourth native/GDB regression checks nested shadowing, alias returns (including
identical operands in both branches), aggregate returns and function-body match
arms. It requires exact selected-return/caller lines with no extra untaken-arm
stops, verifies DWARF and compares ordinary/debug VCDs in both packing modes.
It counts actual callee breakpoints for a scalar local reused under distinct
predicates: both consumers select it, only the first selects it, or only the
second selects it. The call must execute once in each case; an outer untaken
call must not execute. All four inline/shared caller/callee combinations run in
both packing modes, and breakpoint callback failures are collected explicitly.
The cache regression also rejects branch-only readiness flags, keeps separate
width keys, and checks state invalidation rather than restoring stale results.
A fifth regression exercises nested scalar hardware calls, shared helpers and
multiple instances, selected returns with shadowed signed locals, 81-bit
signed/unsigned and real bindings, declared return types, and clocked calls.
Its aggregate parameter/local probe includes one-field wrappers, nested structs,
sub-byte and signed wide leaves, arrays in both directions and negative labels. It checks field
values, inspection sizes and unavailable pruned members; IR/native unit checks
also prove that debug field metadata cannot retain or execute foreign effects.
The hardware aggregate-return probe counts actual source-call stops across
both/first-only/second-only/untaken consumers and checks both integer fields
after GDB `finish` for positive, negative and zero inputs. An aggregate field
containing `abort()` remains runtime-untaken in both ordinary and debug builds.
It checks each observed binding against its captured input, including transient
initial-delta defaults, and requires the settled values and both event inputs.
GDB callback failures are collected explicitly; a successful GDB exit alone is
not a pass. The native fixtures also cover packed wide-state access alignment:
loads/stores must not assume integer ABI alignment for packed members.
A sixth regression checks actual GDB `finish` values for real-returning
identity functions, rather than merely reading their formal arguments. Both
inline and shared bodies return positive and negative values and preserve the
sign of negative zero in both packing modes, with DWARF verification and
ordinary/debug native result and waveform parity. These native boundaries
return double; bitcasts retain the internal integer-bit value contract.
A seventh regression verifies wide call views at 81/129 bits with both inline
hint settings and both packing modes, including large positive/negative values,
zero, narrow/wider consumers and signed/unsigned generic specializations. It
checks source frames, complete declared argument/local values, byte sizes,
return to the actual caller, native results and VCD parity. These packed calls
do not prove shared Process-body eligibility. Automatic wide `finish` decoding
is deliberately not claimed, as explained above.
An eighth regression checks expression `$logic` snapshots for all nine std
states at 9 and 81 bits, known binary values, recursive struct fields, descending
arrays with negative labels and selected/untaken return branches. It also checks
that an unconsumed plane and pruned hardware members stay optimized out, with
native assertions, DWARF verification and ordinary/debug VCD parity in both
packing modes. The existing wide-return regression additionally guards native
formal availability before a narrow callee's source return stop.
A ninth regression checks the actual native GDB `finish` return value for
complete small SysV real/integer aggregates in both field orders, a nested
struct, a two-real array with distinct values and a one-real wrapper. It runs
with both inline hint settings and both packing modes, comparing ordinary/debug
native results and VCD bytes and verifying DWARF. Every hardware invocation is checked against
its captured formals, including intermediate delta-cycle inputs; all settled
positive, negative and signed-zero cases must also occur. These checks cover
only complete one/two-64-bit-leaf aggregate return transport, not general
shared Process-body eligibility or larger/partial/normalized return ABIs.
A canonical-IR unit test separately checks the same boundary in actual shared
Process functions: mixed/reversed/all-real native signatures, canonical i128
call results, module verification and no additional source-call wrapper.
A tenth regression checks actual GDB `finish` for memory-class SysV source
returns: a 24-byte integer/real struct, a normalized 19-byte unsigned[81]/real
struct, and a 43-byte nested signed[81]/real struct with a descending real array.
Every invocation's returned fields are checked against its captured formals,
including intermediate delta inputs, and settled positive/negative/signed-zero
cases are mandatory. Negative signed data uses the full 81-bit literal to avoid
the separately tracked integer-widening defect. The test uses both inline hints
and packing modes, runs ordinary/debug native assertions, compares VCD bytes
and verifies DWARF. The shared-body unit additionally checks void/sret function
and call signatures, canonical i192/i145 values and entry-owned return storage.
Only the private canonical payload is used by executable callers; normalized
source bytes are debugger-facing. These checks do not prove small unaligned,
partial-demand or arbitrary-wide basic-integer return decoding.
An eleventh regression checks actual GDB `finish` for runtime and nonempty-literal
`Char[]` returns. It verifies all Unicode code points and UTF-8 bytes, including
an embedded NUL and one-character literals with i32 executable carriers,
reuses a returned runtime string after `await`, and runs two
test roots with distinct borrowed content. Exact source-call counts are checked;
empty literal specializations must remain void without a new debugger history
value. Both inline hints and packing modes run ordinary/debug native assertions,
VCD parity and DWARF verification. A boundary unit separately verifies the
32-byte source-view prefix, unchanged i32/i64/i193 executable payloads,
handle-only narrowing for metadata, caller decoding and LLVM module validity.
It guards explicitly declared `Char[1]` against acquiring a dynamic-string
return view. These checks do not prove string eligibility for shared Process
bodies or general dynamic-array support; borrowed content is inspected before
its owning test root is cleaned up.
To run the existing native corpus with DWARF enabled:

```bash
bash scripts/guarded-run.sh env SIOXC_DEBUG=1 bash scripts/test-corpus.sh /home/max/siox-tests
```

## How the compiler is tested

- **Unit and integration tests** across the package (`cargo test`).
- **Native backend tests** compile and link focused designs, then assert values
  through the exported word ABI, including multi-word values.
- **Waveform interoperability tests** emit VCD and FST together, decode FST
  with the pinned libfst reader, and compare hierarchy, values, and timestamps.
- **Conformance corpus.** The runnable `.siox` programs (counters, FSMs, a FIFO,
  SPI, RISC-V fragments, …) live in the
  [Siox-lang/siox-tests](https://github.com/Siox-lang/siox-tests) repo. CI checks
  out the corpus and compiles every program through the freshly built compiler,
  so a regression there fails the build.
- **CI** installs an LLVM toolchain, builds, and runs the full test suite plus
  the corpus through the freshly-built compiler.
