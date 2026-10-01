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
highlighted on a dark background. The theme colours siox the way One Dark Pro
colours Rust: keywords purple, types yellow (built-in and user alike, with
literal prefixes and suffixes in the type colour), functions and macros blue,
variables and fields red, numbers and constants orange, strings and characters
green, operators cyan, tick attributes purple italic like Rust's lifetimes,
and labels grey so they never read as keywords.

It covers keywords and directions, word operators (`and`, `xor`, …), types,
character literals (`'0'`), bit strings (`x"AB"`), numbers with unit suffixes
(`10ns`), tick attributes (`clk'event`), `#[...]` directives, VHDL-style
labels (`update: process`), macros (`assert!`), and comments.
