---
name: beamerposter-generic
description: >
  Ultra-generic LaTeX BeamerPoster skill. Produces reusable academic posters
  using XeLaTeX + beamerposter, with full-width TikZ header band, 3-column layout,
  fixed content height, compact lists, and overflow-safe defaults.
compiler: xelatex
---

# BeamerPoster (LaTeX) Skill

This skill defines **how to design, edit, and reason about academic posters**
written in LaTeX using `beamer` + `beamerposter`.

The goal is **not** to generate a one-off poster, but a **stable, reusable poster
architecture** that survives content changes without breaking layout.

---

## Core Design Principles

1. **Structure > Content**
   - Poster layout must remain stable even when text/figures change.
   - Content is split from layout (columns as independent units).

2. **Deterministic Geometry**
   - Explicit page size.
   - Explicit column widths.
   - Explicit column separation.
   - Explicit content height.

3. **Poster Readability**
   - Large fonts (≥ \large body).
   - Strong visual hierarchy (title band > block titles > body).
   - Minimal color palette.

4. **Failure-Safe Compilation**
   - Missing figures/logos must not break compilation.
   - Fallback placeholders are preferred.

---

## Compilation Rules

- Engine: **XeLaTeX only**
- Reason:
  - Required by `fontspec`
  - Stable system font support
- Command:
  ```
  xelatex main.tex
  ```

---

## Canonical File Structure

```
poster/
├── main.tex              % layout + style + header + columns
├── sections/
│   ├── col1.tex          % column 1 content only
│   ├── col2.tex          % column 2 content only
│   └── col3.tex          % column 3 content only
├── figures/
│   ├── logo.png
│   └── fig1.png
└── README.md
```

**Rule:**  
`main.tex` never contains scientific content, only layout logic.

---

## Page Geometry (Non-Negotiable)

Use `beamerposter` with explicit size:

```tex
\usepackage[
  orientation=landscape,
  size=custom,
  width=122,
  height=91.4,
  scale=1.25
]{beamerposter}
```

- 122 × 91.4 cm ≈ 36×48 inch (landscape)
- `scale` is the primary global tuning knob

---

## Typography Rules

```tex
\usepackage{fontspec}
\setmainfont{Times New Roman}
```

- Serif fonts preferred for long reading distance
- Avoid mixing too many fonts

Block fonts:
```tex
\setbeamerfont{block title}{size=\Large,series=\bfseries}
\setbeamerfont{block body}{size=\large}
```

---

## Color System

Single dominant color + optional accent.

```tex
\definecolor{MainColor}{RGB}{170,0,0}

\setbeamercolor{block title}{fg=white,bg=MainColor}
\setbeamercolor{block body}{fg=black,bg=white}
```

Never exceed **2 main colors**.

---

## Header Band (TikZ Overlay)

The poster header is **not part of the normal flow**.

### Why TikZ overlay?
- Full-width control
- Independent of columns
- Predictable placement

Core pattern:

```tex
\begin{tikzpicture}[remember picture,overlay]
  \node[anchor=north west] at (current page.north west) {
    \begin{minipage}{0.98\paperwidth}
      % header content
    \end{minipage}
  };
\end{tikzpicture}
```

Header includes:
- Left: logo
- Center: title + institute
- Right: presenter/contact
- Top/bottom rule lines

---

## Column System (Critical)

Always use:

```tex
\begin{columns}[t,totalwidth=\textwidth]
```

Column widths **must sum to < 1.0**:

```tex
\begin{column}{0.32\textwidth}
```

Column gap:

```tex
\setlength{\columnsep}{0.018\textwidth}
```

### Anti-Bug Rule
If the 3rd column drops to the next row:
1. Reduce `\columnsep`
2. Reduce column width (0.32 → 0.31)
3. Reduce `scale`

---

## Fixed Content Height (Overflow Control)

All columns are wrapped in fixed-height minipages:

```tex
\newlength{\ContentHeight}
\setlength{\ContentHeight}{0.74\textheight}

\begin{minipage}[t][\ContentHeight][t]{\linewidth}
```

This prevents:
- Uneven column bottoms
- Silent content overflow

---

## Block Usage Rules

- Each block answers **one question only**
- Recommended blocks:
  - Background
  - Hypothesis / Key Idea
  - Methods
  - Results
  - Mechanism
  - Conclusions & Outlook

---

## Compact Lists (Mandatory)

Default `itemize` is too loose for posters.

Define once:

```tex
\newenvironment{tightitemize}{
  \begin{itemize}
    \setlength\itemsep{0.35em}
    \setlength\topsep{0.2em}
}{
  \end{itemize}
}
```

Use **only** `tightitemize` inside blocks.

---

## Figures (Failure-Safe Pattern)

Never assume a figure exists.

```tex
\IfFileExists{figures/fig1.png}{
  \includegraphics[width=0.93\linewidth]{figures/fig1.png}
}{
  % placeholder box
}
```

This guarantees compilation at all stages.

---

## Poster Writing Rules (Non-Optional)

- No paragraphs longer than 3 lines
- No more than 6 blocks per column
- Conclusions ≤ 3 bullets
- Outlook ≤ 2 bullets
- Every figure must answer **one question**

---

## Skill Intent

When this skill is active, the model should:

- Think in **layout systems**, not text blobs
- Protect column geometry at all costs
- Prefer structural edits over wording edits
- Warn when content risks overflow
- Never break XeLaTeX compatibility

This is a **poster-engineering skill**, not a text-writing skill.