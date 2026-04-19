# Report template

LaTeX template for the CS6868 research mini-project report. Target length:
**5–10 pages**, including figures, excluding the bibliography.

## Files

- `main.tex` — the report skeleton with all required sections pre-populated.
- `references.bib` — a BibTeX file; add your citations here.

## Build

```sh
latexmk -pdf main.tex
```

or, if you do not have `latexmk`:

```sh
pdflatex main && bibtex main && pdflatex main && pdflatex main
```

This produces `main.pdf`.

## Required sections (do not remove)

The following sections are mandatory and are graded:

1. **Goals** — including a crisp research question.
2. **Background** — enough context for a classmate to follow.
3. **Tasks Undertaken** — implementation + testing / verification.
4. **Evaluation** — experimental setup, results, discussion.
5. **Reflection on the Use of LLMs** — models used, what worked, what
   didn't, what surprised you, what was difficult. See `main.tex` for the
   required sub-headings.
6. **Conclusions** — answer the research question, state limitations.
7. **Contributions** — per-member percentages summing to 100%.

You can add extra sections (e.g., *Related Work*) as needed, as long as the
report stays within 5–10 pages.
