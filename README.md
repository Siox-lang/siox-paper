# siox — goal and purpose

A short paper explaining what the [siox](https://github.com/Siox-lang/sioxc)
hardware description language is for: why it exists, the principles behind
it, a first example, how the compiler works, and the three-phase roadmap.

Read it as [`siox.pdf`](siox.pdf). The source is [`siox.typ`](siox.typ), written
in [Typst](https://typst.app); rebuild the PDF and commit both together.

```bash
typst compile siox.typ          # writes siox.pdf
typst watch siox.typ            # rebuilds on every save
```

Any Typst 0.12 or later works; the document uses only Typst's bundled fonts.

## Syntax highlighting

[`siox.sublime-syntax`](siox.sublime-syntax) is a siox grammar in Sublime
Text's format, and [`siox.tmTheme`](siox.tmTheme) colours it. The paper loads
both with `#set raw(syntaxes: .., theme: ..)`, so ```` ```siox ```` blocks are
highlighted. The theme keeps every category apart: keywords (bold purple),
built-in data types such as `Bit` and `unsigned` (teal), user types (blue),
labels (orange), tick attributes (green), directives (amber), literals
(magenta), strings (navy) and comments (grey). The same file works anywhere syntect
does: copy it into Sublime Text's `Packages/User/`, or into `bat`'s syntax
directory and run `bat cache --build`.

It covers keywords and directions, word operators (`and`, `xor`, …), types,
character literals (`'0'`), bit strings (`x"AB"`), numbers with unit suffixes
(`10ns`), tick attributes (`clk'event`), `#[...]` directives, VHDL-style
labels (`update: process`), macros (`assert!`), and comments.
