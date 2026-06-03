---
name: slide-fit-check
description: Verify that recently-edited slide content actually fits on the slide canvas. Typst silently allows content to overflow the page boundary in slide PDFs (no compile error, just bleed-off), so layout-affecting edits to a `content-block`'s `summary:` need post-build verification. The PostToolUse hook (`slide-fit-trigger.sh`) reminds you on edits to `modules/Session_*/*.typ`.
---

# Slide Fit Check

Typst does not error when content overflows a slide. The element bboxes still
exist in the PDF page stream past the page boundary (`page.rect.y1`), so they
are detectable with `pymupdf` (a.k.a. `fitz`) — but only after the PDF is
built. This skill builds the affected session, locates the edited
content-block(s) in the PDF, and reports any overflow.

## When to run

- After editing a `content-block`'s `summary:` in a slide-emitting module
  (`modules/Session_*/*.typ`). The hook will remind you.
- After adding an `image()`, large `grid()`, extra bullets, or a wider-aspect
  asset to existing summary content.
- When the user reports "spillover" or "content cut off" on a slide.

## When to skip

- Edit only touches a `details:` block (document-only — never on a slide).
- Edit is inside a `content-block-doc-only(...)` (no slide rendered).
- Edit is a typo fix or other change that cannot affect layout (e.g., tweaking
  prose inside `details:`, renaming a variable).

When skipping, briefly say so in your reply ("skipping slide-fit-check —
edit is doc-only") so the user knows you considered it.

## Slide canvas conventions

The dual-format submodule renders slides at **1152 × 648 pt** (16:9). The
nominal `summary:` block is `dy: 65pt, height: 470pt`, but in practice slides
routinely use the full canvas — the page-number footer alone sits at y≈639,
so any threshold tighter than the page boundary itself produces noise.

The reliable check is therefore: **does any element's bbox extend past the
page edge** (`y1 > 648` or `x1 > 1152`)? That is what Typst silently allows
and what visually appears as "spilled over" content in a PDF viewer.

## Workflow

### 1. Identify the session and edited block titles

From the edited file path, extract the session number (e.g.,
`modules/Session_4/1_forward_fx_market.typ` → session 4).

From the diff of *this* turn's edits, list the `content-block(...)` titles
whose `summary:` was modified. Skip `content-block-doc-only` titles.

### 2. Build the session slides PDF

```bash
make build/Session_<N>_*/Session_<N>_slides.pdf
```

If the build fails, stop — fix the build error first; overflow check is moot.

### 3. Locate target page(s) and check overflow

Run a single Python script that takes the session number plus one or more
title strings and reports per-page status. Use `python3` with `pymupdf`
(already installed):

```bash
python3 - <<'PY'
import fitz, glob, sys

SESSION = 4                                    # ← set
TITLES  = ["Forward FX Market Overview"]       # ← set; one or more

PDF = glob.glob(f"build/Session_{SESSION}_*/Session_{SESSION}_slides.pdf")[0]
doc = fitz.open(PDF)

# Slide canvas (from dual_format submodule)
PAGE_W, PAGE_H = 1152, 648
TOL = 2.0                          # ignore sub-pixel overruns

def collect_bboxes(page):
    bboxes = []
    for b in page.get_text("rawdict")["blocks"]:
        for L in b.get("lines", []):
            for s in L.get("spans", []):
                bboxes.append(("text", fitz.Rect(s["bbox"]), s.get("text", "")[:60]))
    for img in page.get_image_info():
        bboxes.append(("image", fitz.Rect(img["bbox"]), ""))
    for d in page.get_drawings():
        bboxes.append(("draw", fitz.Rect(d["rect"]), ""))
    return bboxes

for title in TITLES:
    hits = [i for i, p in enumerate(doc) if title in p.get_text()]
    if not hits:
        print(f"[!] '{title}' not found in any page — title may have changed")
        continue
    for i in hits:
        page = doc[i]
        bboxes = collect_bboxes(page)
        overflow = [b for b in bboxes if b[1].y1 > PAGE_H - TOL or b[1].x1 > PAGE_W - TOL]
        max_y = max((b[1].y1 for b in bboxes), default=0)
        max_x = max((b[1].x1 for b in bboxes), default=0)

        if overflow:
            status = f"OVERFLOW (max y1={max_y:.1f}/{PAGE_H}; max x1={max_x:.1f}/{PAGE_W})"
        else:
            status = "OK"
        print(f"page {i+1:>2}  {status}  — '{title}'")
        if overflow:
            for kind, r, txt in overflow[:5]:
                print(f"           {kind:5s} bbox={tuple(round(v,1) for v in r)}  {txt!r}")
PY
```

This single script:

- finds each title in the PDF,
- collects every text/image/drawing bbox on its page,
- flags **OVERFLOW** when any element extends past the page boundary
  (`y1 > 648 - TOL` or `x1 > 1152 - TOL`),
- prints the offending element rects when there is overflow.

### 4. (Optional) Visual confirmation for borderline cases

If you suspect a visual issue the bbox math missed (overlapping siblings,
image cropped by a container with a clip path, near-edge layout that won't
project well), render the page to PNG and view it:

```bash
python3 - <<'PY'
import fitz
doc = fitz.open("build/Session_<N>_*/Session_<N>_slides.pdf")
for p_num in [<page>]:                  # 1-based
    pix = doc[p_num - 1].get_pixmap(dpi=80)
    pix.save(f"/tmp/slidefit_s<N>_p{p_num}.png")
PY
```

Then `Read` the resulting PNG (Claude can view images directly).

### 5. Report

For each checked page, report one line:

```text
page <N>  — <title> — OK   |   OVERFLOW: <numbers>
```

If overflow, propose a concrete fix:

- shrink font: `#set text(size: <X>em)` inside a `presentation-only[ ... ]` wrapper
- reduce image width (`width: 80%`) or restructure SVG aspect to be flatter
- restructure the grid (drop a column, move bullets to `details:`)
- split into two slides via separate `content-block` calls

If everything passes, say so in **one line**. Do not fabricate issues.

## Why programmatic, not visual-only

The original draft of this skill assumed visual inspection of rendered PNGs,
similar to how a human checks a slide. The bbox-based check above is more
reliable: Typst writes the off-page text/image coordinates into the PDF stream
verbatim, so a numerical comparison against `page.rect` deterministically
detects overflow without depending on the model's image-reading judgment.
Reserve PNG inspection for the borderline cases the bbox check cannot
catch (overlapping siblings, intra-page collisions, asymmetric layouts).

## Evolving this skill

When a slide overflow occurs that this check missed, add a new detection rule
here (e.g., new collision class, new dual-format-region constants if the
submodule's slide template changes). The tolerance constants (`TOL`,
`INNER_BOT`, `PAGE_H`) are the natural place to evolve.
