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

// A timing diagram. Each signal is `(name, spec)` or `(name, spec, labels)`;
// `spec` has one character per cell: `0`/`1` a level, `z` high impedance,
// `x` an unknown or conflicting value, `=` a new bus value (its text taken in
// turn from `labels`), and `.` the previous cell continued. A row of `!` and
// `_` is a process's activity instead: `!` a cell in which it runs (labelled
// in turn from `labels`), `_` a cell in which it is suspended; an optional
// fourth element colours it. `marks` draws a dashed line at the start of the
// given cells; `axis` labels cells underneath.
#let wave(cells: 16, marks: (), axis: (), label-width: 1.9cm, ..signals) = layout(size => {
  let width = size.width - label-width
  let w = width / cells
  let h = 17pt
  let (hi, lo, mid) = (3.5pt, h - 3.5pt, h / 2)
  let slant = calc.min(2.5pt, w / 4)
  let ink = 0.75pt + luma(35)
  let level-y(kind) = if kind == "1" { hi } else if kind == "0" { lo } else { mid }
  let rows = ()
  for signal in signals.pos() {
    let (name, spec) = (signal.at(0), signal.at(1))
    let labels = signal.at(2, default: ())
    let colour = signal.at(3, default: c-ir)
    if spec.contains("!") {
      let shapes = ()
      for m in marks {
        shapes.push(place(top + left, line(start: (m * w, 0pt), end: (m * w, h),
          stroke: (paint: luma(150), thickness: 0.5pt, dash: "dashed"))))
      }
      shapes.push(place(top + left, line(start: (0pt, mid), end: (width, mid),
        stroke: 0.5pt + luma(190))))
      let next-label = 0
      for (i, ch) in spec.clusters().enumerate() {
        if ch != "!" { continue }
        let label = labels.at(next-label, default: none)
        next-label += 1
        shapes.push(place(top + left, dx: i * w + 0.6pt, dy: hi - 0.5pt,
          box(width: w - 1.2pt, height: lo - hi + 1pt, radius: 1.5pt,
            fill: colour.lighten(75%), stroke: 0.6pt + colour,
            align(center + horizon, text(size: 6.8pt, if label == none { [] } else { label })))))
      }
      rows.push(align(right + horizon, text(size: 8pt, name)))
      rows.push(box(width: width, height: h, shapes.join()))
      continue
    }
    // Runs of one state: (kind, label, first cell, end cell).
    let runs = ()
    let next-label = 0
    for (i, ch) in spec.clusters().enumerate() {
      if ch == "." and runs.len() > 0 {
        runs.at(-1).at(3) = i + 1
      } else {
        let label = none
        if ch == "=" {
          label = labels.at(next-label, default: none)
          next-label += 1
        }
        runs.push((ch, label, i, i + 1))
      }
    }
    let shapes = ()
    for m in marks {
      shapes.push(place(top + left, line(start: (m * w, 0pt), end: (m * w, h),
        stroke: (paint: luma(150), thickness: 0.5pt, dash: "dashed"))))
    }
    let previous = none
    for (kind, label, first, end) in runs {
      let (x0, x1) = (first * w, end * w)
      if kind in ("0", "1") {
        let y = level-y(kind)
        if previous in ("0", "1") and previous != kind {
          shapes.push(place(top + left, line(start: (x0, hi), end: (x0, lo), stroke: ink)))
        } else if previous in ("z", "x", "=") {
          shapes.push(place(top + left, line(start: (x0, mid), end: (x0 + slant, y), stroke: ink)))
          x0 = x0 + slant
        }
        shapes.push(place(top + left, line(start: (x0, y), end: (x1, y), stroke: ink)))
      } else if kind == "z" {
        let start = x0
        if previous in ("0", "1") {
          shapes.push(place(top + left, line(start: (x0, level-y(previous)), end: (x0 + slant, mid), stroke: ink)))
          start = x0 + slant
        }
        shapes.push(place(top + left, line(start: (start, mid), end: (x1, mid),
          stroke: 0.75pt + rgb("#2b6cb0"))))
      } else if kind in ("=", "x") {
        let fill = if kind == "x" { rgb("#e53e3e").lighten(78%) } else { rgb("#2b6cb0").lighten(88%) }
        shapes.push(place(top + left, polygon(fill: fill, stroke: ink,
          (x0, mid), (x0 + slant, hi), (x1 - slant, hi), (x1, mid), (x1 - slant, lo), (x0 + slant, lo))))
        let text-label = if kind == "x" and label == none { [X] } else { label }
        if text-label != none {
          shapes.push(place(top + left, dx: x0, box(width: x1 - x0, height: h,
            align(center + horizon, text(size: 7.4pt, text-label)))))
        }
      }
      previous = kind
    }
    rows.push(align(right + horizon, text(size: 8pt, name)))
    rows.push(box(width: width, height: h, shapes.join()))
  }
  if axis.len() > 0 {
    rows.push([])
    rows.push(box(width: width, height: 9pt, axis.map(((cell, body)) =>
      place(top + left, dx: cell * w - 1pt, text(size: 7pt, fill: luma(90), body))).join()))
  }
  grid(columns: (label-width, width), column-gutter: 4pt, row-gutter: 2pt, ..rows)
})

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
