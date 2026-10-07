// Shared layout and helpers for the siox paper.

// One Dark Pro background and foreground, used by code blocks.
#let code-bg = rgb("#282c34")
#let code-fg = rgb("#abb2bf")

#let paper(body) = {
  set document(
    title: "siox: Purpose and Design",
    author: "The siox project",
  )
  set page(
    paper: "a4",
    margin: (x: 2.4cm, y: 2.6cm),
    numbering: "1",
    number-align: center,
  )
  set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
  set par(justify: true, leading: 0.62em)
  set heading(numbering: "1.1", supplement: [§])
  show heading.where(level: 1): it => {
    // Chapters start a page; part dividers and the contents title handle
    // their own placement.
    if it.numbering != none { pagebreak(weak: true) }
    block(above: 1.2em, below: 1em, text(size: 16pt, it))
  }
  show heading.where(level: 2): it => block(above: 1.4em, below: 0.7em, text(size: 12pt, it))
  show heading.where(level: 3): it => block(above: 1.1em, below: 0.6em, text(size: 10.5pt, it))
  // siox snippets are highlighted with the grammar and theme beside this file.
  set raw(syntaxes: "siox.sublime-syntax", theme: "siox.tmTheme")
  show raw.where(block: true): it => block(
    fill: code-bg,
    inset: (x: 10pt, y: 8pt),
    radius: 3pt,
    width: 100%,
    breakable: true,
    text(size: 8.6pt, fill: code-fg, it),
  )
  show raw.where(block: false): it => text(size: 9.4pt, it)
  set table(stroke: none, inset: (x: 6pt, y: 4.5pt))
  show table: set par(justify: false)
  body
}

// A part divider: an unnumbered, outlined heading on its own page.
#let part(title) = {
  pagebreak(weak: true)
  v(5cm)
  text(size: 24pt, weight: "bold", title)
  // The outline and PDF bookmarks list the part; the page shows it large.
  place(hide(heading(level: 1, numbering: none, outlined: true, bookmarked: true, title)))
}

// A short highlighted statement of principle.
#let principle(body) = block(
  inset: (left: 10pt, y: 4pt),
  stroke: (left: 2pt + luma(150)),
  emph(body),
)

// Where a feature stands, shown beside its heading.
#let status(kind) = {
  let (label, colour) = if kind == "done" {
    ("implemented", rgb("#2f855a"))
  } else if kind == "partial" {
    ("partly implemented", rgb("#b7791f"))
  } else if kind == "proposal" {
    ("proposal", rgb("#6b46c1"))
  } else if kind == "phase2" {
    ("Phase 2", rgb("#2b6cb0"))
  } else if kind == "phase3" {
    ("Phase 3", rgb("#c05621"))
  } else {
    (kind, luma(100))
  }
  box(
    inset: (x: 5pt, y: 2pt),
    outset: (y: 1pt),
    radius: 2pt,
    fill: colour.lighten(85%),
    stroke: 0.5pt + colour,
    text(size: 8pt, fill: colour, weight: "bold", label),
  )
}

// A note that an example is illustrative, not settled syntax.
#let sketch = text(size: 8.5pt, fill: luma(90), style: "italic")[
  Illustrative sketch: the syntax below is not designed yet.
]

// Diagrams, drawn with Typst's own shapes so the document needs no package.
// Colours name the part of the system a box belongs to.
#let c-front = rgb("#2b6cb0")    // compiler front end
#let c-ir = rgb("#6b46c1")       // the IR
#let c-back = rgb("#2f855a")     // code generation and output
#let c-run = rgb("#c05621")      // the runtime
#let c-muted = luma(120)

// One box of a flowchart.
#let step(body, colour: c-muted, width: auto) = box(
  width: width,
  inset: (x: 7pt, y: 5pt),
  radius: 3pt,
  fill: colour.lighten(85%),
  stroke: 0.6pt + colour,
  align(center, text(size: 8.4pt, body)),
)

// An arrow between boxes, optionally labelled.
#let arrow(dir, label: none) = {
  let glyph = (
    right: sym.arrow.r, left: sym.arrow.l, up: sym.arrow.t, down: sym.arrow.b,
    down-right: sym.arrow.br, down-left: sym.arrow.bl,
  ).at(dir)
  let mark = text(size: 13pt, fill: luma(70), glyph)
  if label == none { return align(center + horizon, mark) }
  let note = text(size: 7.4pt, fill: luma(80), style: "italic", label)
  align(center + horizon, if dir in ("right", "left") {
    stack(dir: ttb, spacing: 1pt, note, mark)
  } else {
    stack(dir: ltr, spacing: 3pt, mark, note)
  })
}

// Boxes joined left to right by arrows.
#let flow(..steps) = {
  let items = steps.pos()
  grid(
    columns: items.len() * 2 - 1,
    align: center + horizon,
    column-gutter: 3pt,
    ..items.intersperse(arrow("right")),
  )
}

// A timeline: one row per lane, `(label, blocks)`, each block
// `(start, length, body, colour)` in slots of the axis. `marks` draws a
// dashed boundary before the given slots; `axis` labels slots underneath.
#let lanes(slots: 12, marks: (), axis: (), label-width: 1.9cm, ..rows) = {
  let cells = ()
  for (label, blocks) in rows.pos() {
    cells.push(align(right + horizon, text(size: 8pt, label)))
    let at = 0
    for (start, length, body, colour) in blocks.sorted(key: b => b.at(0)) {
      for _ in range(at, start) { cells.push([]) }
      cells.push(grid.cell(colspan: length, box(
        width: 100%, height: 15pt, radius: 2pt,
        fill: colour.lighten(80%), stroke: 0.6pt + colour,
        align(center + horizon, text(size: 7.6pt, body)),
      )))
      at = start + length
    }
    for _ in range(at, slots) { cells.push([]) }
  }
  if axis.len() > 0 {
    cells.push([])
    let labels = (:)
    for (slot, body) in axis { labels.insert(str(slot), body) }
    for slot in range(slots) {
      cells.push(align(left, text(size: 7pt, fill: luma(90), labels.at(str(slot), default: []))))
    }
  }
  grid(
    columns: (label-width,) + (1fr,) * slots,
    column-gutter: 1.5pt,
    row-gutter: 4pt,
    ..marks.map(slot => grid.vline(x: slot + 1, stroke: (paint: luma(120), thickness: 0.6pt, dash: "dashed"))),
    ..cells,
  )
}

// Code inside a diagram, at the diagram's own size.
#let mono(body) = text(font: "DejaVu Sans Mono", size: 0.92em, body)

// A diagram as a numbered figure that never splits across pages.
#let diagram(body, caption: none) = figure(
  block(breakable: false, width: 100%, inset: (y: 4pt), body),
  kind: image,
  caption: caption,
)

#let title-page() = {
  set page(numbering: none)
  align(center)[
    #v(3.5cm)
    #text(size: 30pt, weight: "bold")[siox]
    #v(0.3cm)
    #text(size: 14pt)[A hardware description language for the whole circuit]
    #v(0.5cm)
    #text(size: 11pt, fill: luma(80))[Purpose and design · October 2026]
    #v(1.5cm)
  ]
  block(inset: (x: 1.2cm))[
    *Abstract.* siox ("silicon oxide") is a hardware description language and
    compiler. It describes digital circuits with the precise semantics of VHDL
    and the structure of Rust: entities and processes, nine-value IEEE logic
    and delta cycles, written with modules, traits, generics and one strict type
    system. Designs compile through LLVM to native simulators that run their own
    tests and write VCD or FST waveforms.

    This document explains what siox is for and what it will do. Part I gives
    the purpose and the principles. Part II describes the digital language as it
    exists today. Part III describes where it is going: the language features
    already designed, analogue and mixed-signal modelling, and the design and
    synthesis layer that turns models into hardware. Each feature is marked with
    where it stands: #status("done"), #status("partial"), #status("proposal"),
    #status("phase2") or #status("phase3").
  ]
  pagebreak()
}
