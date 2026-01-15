# BeamerPoster Template (XeLaTeX)

This is a **generic, reusable** poster template based on:
- `beamer` + `beamerposter`
- XeLaTeX fonts via `fontspec`
- Full-width header band using TikZ overlay
- 3-column layout with fixed content height
- Compact lists and overflow-safe defaults

## Compile

```bash
xelatex main.tex
```

## Where to edit

- `main.tex`
  - poster size (width/height/scale)
  - theme color `MainColor`
  - title/author/institute
  - header spacing (two `\vspace{...}`)
  - column widths and `\columnsep`

- `sections/col1.tex`, `sections/col2.tex`, `sections/col3.tex`
  - your content blocks

## Images

Put images in `figures/`:
- `figures/logo.png`
- `figures/fig1.png` (example)

The template compiles even if images are missing (shows placeholder boxes).

## Tips to avoid layout bugs

1) Third column drops to next row:
- reduce `\columnsep`
- reduce column width from `0.32` to `0.31`
- reduce beamerposter `scale`

2) Bottom overflow:
- reduce `\ContentHeight`
- reduce block body font size
- reduce list spacing in `tightitemize`

Generated on: 2026-01-13
