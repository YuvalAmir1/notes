#import "@local/notes:0.1.0": paper
#show: paper.with(
  title: "{{title}}",
  authors: (
    (name: "{{author}}", affiliation: "Department, University, City, Country", email: "you@example.com"),
  ),
  date: "{{date}}",
  abstract: [
    The question the paper asks, how it was studied, what was found, and why that matters.
  ],
  keywords: ("first keyword", "second keyword"),
  columns: 1, // 2 for two columns
)

= Introduction

{{cursor}}

= Methods

= Results

= Discussion

= Conclusion

// Cite with @key, and list what you cite from a .bib file beside the note:
// #bibliography("references.bib")
