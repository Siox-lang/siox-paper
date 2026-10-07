# siox — purpose and design

A document explaining what the [siox](https://github.com/Siox-lang/sioxc)
hardware description language is for and what it will do. Read it as
[`siox.pdf`](siox.pdf).

- **Part I · Purpose** — why another HDL, the principles behind siox, and a
  first example.
- **Part II · The digital language** — what siox does today: program
  structure, behaviour, types, abstraction, metadata and directives,
  verification, and the compiler.
- **Part III · Where siox is going** — the designed features (pipelined
  functions, macros, `core`/`std`, entity methods, the standard library, the
  compiler foundations), Phase 2 analogue and mixed signal, Phase 3 design and
  synthesis, and the tools around the compiler.
- **Appendix** — keywords, system attributes, directives, lints, glossary.

Every feature carries its status: implemented, partly implemented, proposal,
planned, Phase 2 or Phase 3.

## Reference documentation

[`docs/`](docs/README.md) holds the compiler's reference set, moved here from
sioxc: the language specification ([`language.md`](docs/language.md), the
authority for syntax and semantics), the standard library, simulation,
testing, interoperability, the compiler architecture, the Phase 1 audit and
the roadmap. Design proposals stay with the compiler, in
[sioxc's `docs/proposals/`](https://github.com/Siox-lang/sioxc/tree/main/docs/proposals).

## Waveforms

The timing diagrams that say they come from the simulator were drawn from the
VCD of the programs in [`waves/`](waves): build each with
`sioxc --test <file>.siox -o t`, run `./t -o <file>.vcd`, and sample it with
`python3 waves/vcd2wave.py <file>.vcd <cell-ns> <cells> <signal>...`, which
prints the strings the paper's `wave` helper draws.

## Building

The source is [`siox.typ`](siox.typ), with shared layout in
[`style.typ`](style.typ) and one file per chapter in [`chapters/`](chapters),
written in [Typst](https://typst.app). Rebuild the PDF and commit both
together:

```bash
typst compile siox.typ          # writes siox.pdf
typst watch siox.typ            # rebuilds on every save
```

Any Typst 0.12 or later works; the document uses only Typst's bundled fonts.

## Syntax highlighting

[`siox.sublime-syntax`](siox.sublime-syntax) is a siox grammar in Sublime
Text's format, and [`siox.tmTheme`](siox.tmTheme) colours it. The paper loads
both with `#set raw(syntaxes: .., theme: ..)`, so ```` ```siox ```` blocks are
highlighted on a dark background. siox takes its program structure from Rust
and its hardware model from VHDL, and the theme (One Dark Pro's palette) keeps
each part in its usual colours. From Rust: keywords purple, user types and
generics yellow, functions, macros and directives blue, variables red, numbers
orange, strings green, operators cyan. From VHDL: built-in hardware types
(`Bit`, `Logic`, `unsigned`, `time`) cyan like `std_logic`, with unit suffixes
and radix prefixes, tick attributes (`'event`, `'length`) orange italic, logic
literals (`'0'`, `'Z'`) green. Labels are grey, so they never read as
keywords.

It covers keywords and directions, word operators (`and`, `xor`, …), types,
character literals (`'0'`), bit strings (`x"AB"`), numbers with unit suffixes
(`10ns`), tick attributes (`clk'event`), `#[...]` directives, VHDL-style
labels (`update: process`), macros (`assert!`), and comments.
