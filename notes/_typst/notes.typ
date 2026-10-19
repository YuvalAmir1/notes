// The look of notes, imported by the templates: Stylix's sans-serif font,
// and each paragraph, heading and list laid out in the direction of its
// first letter, so Hebrew ones run right to left; all of a list goes its
// way, the lists in it too. Papers look as science papers do, in a serif
// font; a notebook is one PDF of the notes it includes. In the live preview
// (tinymist's, given `--input preview=true`), the palette's colours too:
// Emacs's, as inputs by base16 name (`--input base00=#1e1e2e`), else the
// one it starts with; drawings made for white paper, as Typst's libraries
// make them, take them as well. Code is coloured as Emacs colours it, in
// the palette there and in colours for paper in the PDF: red for errors
// alone.

#let preview = sys.inputs.at("preview", default: none) == "true"
#let palette = (
  base00: "@base00@",
  base03: "@base03@",
  base05: "@base05@",
  base08: "@base08@",
  base09: "@base09@",
  base0A: "@base0A@",
  base0B: "@base0B@",
  base0C: "@base0C@",
  base0D: "@base0D@",
  base0E: "@base0E@",
).pairs().map(((name, color)) => (name, rgb(sys.inputs.at(name, default: color)))).to-dict()
#let background = palette.base00
#let foreground = palette.base05

// A direction mark counts as a letter: U+200F (RLM) as a Hebrew one, U+200E
// (LRM) as a Latin one. One at a paragraph's start sets its direction, as
// in Emacs.
#let rtl-letter = regex("[\p{Hebrew}\p{Arabic}\u{200F}]")
#let letter = regex("[\p{L}\u{200E}\u{200F}]")

/// The first letter in some content, or none.
#let first-letter(it) = {
  if type(it) == str {
    let found = it.match(letter)
    return if found != none { found.text }
  }
  if type(it) != content { return none }
  if it.has("text") { return first-letter(it.text) }
  if it.has("children") {
    for child in it.children {
      let found = first-letter(child)
      if found != none { return found }
    }
    return none
  }
  if it.has("body") { return first-letter(it.body) }
  if it.has("term") { return first-letter(it.term) }
  if it.has("child") { return first-letter(it.child) }
  none
}

/// Whether IT's first letter is Hebrew (or Arabic).
#let rtl-first(it) = {
  let found = first-letter(it)
  found != none and found.match(rtl-letter) != none
}

/// IT, right to left when its first letter is Hebrew (or Arabic), unless
/// it's in a list.
#let by-first-letter(it) = context {
  if text.dir == auto and rtl-first(it) {
    set text(dir: rtl)
    it
  } else {
    it
  }
}

/// A list, all of it in the direction of its first letter, unless it's in
/// another list.
#let list-by-first-letter(it) = context {
  if text.dir == auto {
    set text(dir: if rtl-first(it) { rtl } else { ltr })
    it
  } else {
    it
  }
}

/// In the preview, what's drawn for white paper in the palette's colours:
/// black, white and the greys between them along the palette's, from its
/// text's colour to its background's; pale tints, as boxes are filled
/// with, as dark (or light) on its background as they were light on white.
/// Other colours stay. The colours made are oklab, which it leaves.
#let (bg-l, bg-a, bg-b, _) = background.oklab().components()
#let (fg-l, fg-a, fg-b, _) = foreground.oklab().components()
#let repaint(paint) = {
  if type(paint) != color or paint.space() == oklab or paint in (foreground, background) {
    return paint
  }
  let (l, a, b, alpha) = paint.oklab().components()
  let chroma = calc.sqrt(a * a + b * b)
  if chroma >= 0.02 and (l < 70% or chroma >= 0.15) { return paint }
  let t = 1 - l / 100%
  oklab(bg-l + t * (fg-l - bg-l), a + bg-a + t * (fg-a - bg-a), b + bg-b + t * (fg-b - bg-b), alpha)
}

/// A fill repainted, or each of a table's.
#let refill(it) = {
  if type(it) == function { return (..args) => refill(it(..args)) }
  if type(it) == array { return it.map(refill) }
  repaint(it)
}

/// A stroke repainted, black if it has no colour, or each of its sides or
/// a table's.
#let restroke(it) = {
  if type(it) == function { return (..args) => restroke(it(..args)) }
  if type(it) == array { return it.map(restroke) }
  if it in (none, auto) { return it }
  let keys = ("paint", "thickness", "cap", "join", "dash", "miter-limit")
  if type(it) == dictionary and it.keys().all(key => key not in keys) {
    return it.pairs().map(((side, it)) => (side, restroke(it))).to-dict()
  }
  let old = stroke(it)
  let paint = if old.paint == auto { foreground } else { repaint(old.paint) }
  if paint == old.paint { return it }
  stroke(paint: paint, thickness: old.thickness, cap: old.cap, join: old.join, dash: old.dash, miter-limit: old.miter-limit)
}

/// IT, an ELEMENT that draws, repainted: made again with its fields, those
/// of POSITIONAL, if any, after the others, and its label, or one that marks
/// it done. A shape with neither stroke nor fill gets the stroke it would
/// have in black.
#let repainted(element, positional: none, it) = {
  let label = it.at("label", default: none)
  if label == <notes-repainted> { return it }
  let (fill, stroke) = (it.at("fill", default: none), it.at("stroke", default: none))
  let changes = (:)
  let new-fill = refill(fill)
  if new-fill != fill { changes.fill = new-fill }
  if stroke == auto and fill == none and element in (rect, square, circle, ellipse, polygon, curve) {
    changes.stroke = 1pt + foreground
  } else {
    let new-stroke = restroke(stroke)
    if new-stroke != stroke { changes.stroke = new-stroke }
  }
  // Labelled, it can't be marked done: a colour it gets is oklab, but a
  // function isn't anything to tell by.
  if changes.len() == 0 or (label != none and changes.values().any(it => type(it) == function)) {
    return it
  }
  let fields = it.fields() + changes
  let _ = fields.remove("label", default: none)
  let rest = if positional == none { () } else { fields.remove(positional, default: none) }
  if type(rest) != array { rest = (rest,) }
  [#element(..fields, ..rest)#if label == none { <notes-repainted> } else { label }]
}

/// BODY with what's drawn for white paper repainted, and its black text
/// (and white, as on black) in the palette's.
#let in-palette(body) = {
  show curve: repainted.with(curve, positional: "components")
  show polygon: repainted.with(polygon, positional: "vertices")
  show line: repainted.with(line)
  show rect: repainted.with(rect, positional: "body")
  show square: repainted.with(square, positional: "body")
  show circle: repainted.with(circle, positional: "body")
  show ellipse: repainted.with(ellipse, positional: "body")
  show box: repainted.with(box, positional: "body")
  show block: repainted.with(block, positional: "body")
  show grid: repainted.with(grid, positional: "children")
  show table: repainted.with(table, positional: "children")
  show highlight: repainted.with(highlight, positional: "body")
  show text.where(fill: black): set text(fill: foreground)
  show text.where(fill: rgb("#000000")): set text(fill: foreground)
  show text.where(fill: white): set text(fill: background)
  show text.where(fill: rgb("#ffffff")): set text(fill: background)
  show math.equation: it => context {
    if text.fill in (black, rgb("#000000")) {
      text(fill: foreground, it)
    } else if text.fill in (white, rgb("#ffffff")) {
      text(fill: background, it)
    } else {
      it
    }
  }
  // Drawings made as SVG, as Graphviz's.
  show image: it => {
    if type(it.source) != bytes or it.format != "svg" or it.has("label") { return it }
    let svg = str(it.source)
    let new = svg
      .replace("\"black\"", "\"" + foreground.to-hex() + "\"")
      .replace("\"white\"", "\"" + background.to-hex() + "\"")
    if new == svg { return it }
    let fields = it.fields()
    let _ = fields.remove("source")
    image(bytes(new), ..fields)
  }
  body
}

/// A theme for code (tmTheme) in COLORS, by base16 name, as Emacs (and
/// Helix) colour code, with PLAIN for operators.
#let code-theme(colors, plain) = {
  let rules = (
    ("comment", colors.base03, "italic"),
    ("string", colors.base0B),
    ("constant", colors.base09),
    ("constant.character.escape, string.regexp", colors.base0C),
    ("keyword, storage, variable.language", colors.base0E),
    // In f-strings, code.
    ("keyword.operator, meta.interpolation", plain),
    ("entity.name, variable.function, support", colors.base0D),
    ("entity.name.type, entity.name.class, entity.name.struct, support.type, support.class, meta.annotation", colors.base0A),
    ("entity.name.tag, entity.name.label, markup.other.reference, markup.underline.link, markup.quote", colors.base0C),
    ("entity.other.attribute-name", colors.base09),
    ("meta.mapping.key string", colors.base0D),
    ("markup.heading, entity.name.section", colors.base0D, "bold"),
    ("markup.bold", colors.base0A, "bold"),
    ("markup.italic", colors.base0E, "italic"),
    ("markup.raw, markup.inserted, meta.diff.header.to-file", colors.base0B),
    ("markup.deleted, meta.diff.header.from-file", colors.base0E),
    ("punctuation.definition.list, meta.diff.range", colors.base0D),
    ("invalid", colors.base08),
  )
  let key(name, value) = "<key>" + name + "</key><string>" + value + "</string>"
  // The first entry is the theme's own settings, none here.
  bytes(
    "<plist version=\"1.0\"><dict><key>settings</key><array><dict><key>settings</key><dict/></dict>"
      + rules
        .map(((scope, color, ..style)) => {
          "<dict>" + key("scope", scope) + "<key>settings</key><dict>" + key("foreground", color.to-hex())
          for it in style { key("fontStyle", it) }
          "</dict></dict>"
        })
        .join()
      + "</array></dict></plist>",
  )
}

/// Code's colours on paper, by the base16 names of what they colour:
/// Typst's own, but keywords, numbers and types, which it has red.
#let ink = (
  base03: rgb("#74747c"),
  base08: rgb("#d73948"),
  base09: rgb("#b35900"),
  base0A: rgb("#8f6a00"),
  base0B: rgb("#198810"),
  base0C: rgb("#1d6c76"),
  base0D: rgb("#4b69c6"),
  base0E: rgb("#8b41b1"),
)

/// What notes and papers share: the preview's colours, its drawings' too,
/// code's colours, highlights, and each paragraph, heading and list in the
/// direction of its first letter.
#let shared(body) = {
  set raw(theme: if preview { code-theme(palette, foreground) } else { code-theme(ink, black) })
  set page(fill: background) if preview
  set text(fill: foreground) if preview
  set line(stroke: foreground) if preview
  set table(stroke: foreground) if preview
  set highlight(fill: rgb("#fffd11")) if preview
  // A highlight's text in the palette's darker colour, on its yellow.
  show highlight.where(fill: rgb("#fffd11")): set text(fill: if bg-l < fg-l { background } else { foreground })
  show: it => if preview { in-palette(it) } else { it }
  show par: by-first-letter
  show heading: by-first-letter
  show list: list-by-first-letter
  show enum: list-by-first-letter
  show terms: list-by-first-letter
  show quote.where(block: true): by-first-letter
  // A link to another note (Space n l) is its text: Emacs follows it (g f).
  show link: it => if type(it.dest) == str and it.dest.ends-with(".typ") { it.body } else { it }
  body
}

/// The page, font and spacing of notes and notebooks. With SCROLL, a page
/// grows to hold all that's on it, to scroll through as a web page, and has
/// no number.
#let sans(scroll: false, body) = {
  set page(paper: "a4", margin: (x: 2.2cm, y: 2.4cm), numbering: "1")
  set page(height: auto, numbering: none) if scroll
  set text(font: ("@sans@", "Noto Sans Hebrew"), size: 11pt)
  set par(leading: 0.75em, spacing: 1.2em)
  show heading: set block(above: 1.6em, below: 0.9em)
  show: shared
  body
}

/// A title, large, with the date under it.
#let title-block(title, date) = if title != none {
  by-first-letter(block(below: 1.8em, {
    text(size: 1.9em, weight: "bold", title)
    if date != none {
      linebreak()
      text(fill: if preview { foreground.transparentize(40%) } else { luma(45%) }, date)
    }
  }))
}

/// A note: `#show: note.with(title: "…", date: "…")` at its top; with
/// `scroll: true` it's one long page, not A4 pages.
#let note(title: none, date: none, scroll: false, body) = {
  set document(title: title)
  show: sans.with(scroll: scroll)
  // Where a notebook finds it.
  if title != none [#metadata(title) <notes-title>]
  title-block(title, date)
  body
}

/// A notebook: one PDF of the notes it includes, each from a new page, after
/// a page with its title and theirs. `#show: notebook.with(title: "…")` at
/// its top, then `#include "note.typ"` for each note, in order. With
/// `scroll: true` its pages grow to hold all of each.
#let notebook(title: none, date: none, scroll: false, body) = {
  show: sans.with(scroll: scroll)
  title-block(title, date)
  context for found in query(<notes-title>) {
    let at = found.location()
    by-first-letter(link(at, block(width: 100%, spacing: 0.9em, {
      found.value
      box(width: 1fr, repeat(gap: 0.25em)[.])
      str(counter(page).at(at).first())
    })))
  }
  body
  // After its notes, which set the PDF's title each.
  set document(title: title)
}

/// A paper, as science papers look: `#show: paper.with(title: "…",
/// authors: (…), abstract: […])` at its top. Each author is a dictionary
/// with a `name`, and an `affiliation` and an `email` if you like.
/// `columns: 2` sets the text in two columns, under the title and abstract.
#let paper(
  title: none,
  authors: (),
  date: none,
  abstract: none,
  keywords: (),
  columns: 1,
  body,
) = {
  let size = if columns == 1 { 11pt } else { 10pt }
  set document(title: title, author: authors.map(author => author.name))
  set page(
    paper: "a4",
    margin: if columns == 1 { (x: 2.8cm, y: 3cm) } else { (x: 1.8cm, y: 2.5cm) },
    numbering: "1",
    columns: columns,
  )
  set text(font: ("New Computer Modern", "Noto Serif Hebrew"), size: size)
  set par(justify: true, leading: 0.6em, spacing: 0.6em, first-line-indent: 1.5em)
  set heading(numbering: "1.1")
  show heading: set text(size: size)
  show heading.where(level: 1): set text(size: size * 1.3)
  show heading.where(level: 2): set text(size: size * 1.1)
  show heading: set block(above: 1.4em, below: 0.9em)
  set math.equation(numbering: "(1)")
  show figure.where(kind: table): set figure.caption(position: top)
  show figure.caption: set text(size: 0.9em)
  set bibliography(title: "References")
  show: shared
  if title != none [#metadata(title) <notes-title>]

  let affiliations = authors
    .map(author => author.at("affiliation", default: none))
    .filter(it => it != none)
    .dedup()
  let numbered = affiliations.len() > 1
  let emails = authors.map(author => author.at("email", default: none)).filter(it => it != none)
  let small = text.with(size: 0.9em)

  // The title, authors and abstract, across the columns.
  place(top, scope: "parent", float: true, clearance: 2em, {
    set par(first-line-indent: 0em, spacing: 0.8em)
    align(center, {
      block(below: 1.2em, text(size: 1.75em, weight: "bold", title))
      authors
        .map(author => {
          author.name
          let affiliation = author.at("affiliation", default: none)
          if numbered and affiliation != none {
            super(str(affiliations.position(it => it == affiliation) + 1))
          }
        })
        .join(", ", last: " and ")
      if affiliations.len() > 0 {
        parbreak()
        small(affiliations
          .enumerate()
          .map(((i, affiliation)) => if numbered { super(str(i + 1)) + affiliation } else { affiliation })
          .join(linebreak()))
      }
      if emails.len() > 0 {
        parbreak()
        small(emails.map(email => link("mailto:" + email, email)).join(", "))
      }
      if date != none {
        parbreak()
        small(date)
      }
    })
    if abstract != none {
      v(0.8em)
      pad(x: if columns == 1 { 2.5em } else { 0em }, small({
        align(center, strong[Abstract])
        abstract
        if keywords.len() > 0 {
          parbreak()
          [_Keywords:_ #keywords.join(", ")]
        }
      }))
    }
  })
  body
}
