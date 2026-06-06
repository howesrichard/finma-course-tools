---
name: box-fit-check
description: Verify that document-mode callout boxes (takeaways-box, definition-box, example-box, concept-box) actually contain their content. These boxes wrap their body in `block(breakable: false)`, so when the body is taller than a page Typst silently lets the content spill out below the box border and off the bottom of the page (no compile error). Layout-affecting edits to box content in `details:`/document prose need post-build verification. The PostToolUse hook (`slide-fit-trigger.sh`) reminds you on edits to `modules/Session_*/*.typ`.
---

# Box Fit Check

The document-mode callout boxes — `concept-box` and its wrappers `takeaways-box`,
`definition-box`, `example-box` — render their body inside
`block(breakable: false)` ([`document_functions.typ`](../../../finma-course-template/typst-dual-format/document_functions.typ) `concept-box`).
A non-breakable block cannot split across pages, so when its content exceeds the
page height Typst does **not** error and does **not** scale the content to fit.
Instead the coloured border rect clamps at the bottom content margin while the
inner text keeps flowing **below the border and off the bottom of the page** —
the "squashing" / spillover you see in a PDF viewer.

This is the document-mode sibling of `slide-fit-check`. Same silent-overflow
class, different surface: instead of one fixed slide canvas, the box can land on
any page of a multi-page A4 document, and the detector keys on the **box border
colour** rather than a content-block title.

## When to run

- After editing the body of a callout box (`takeaways-box`, `definition-box`,
  `example-box`, `concept-box`) — typically inside a `details:` block or other
  document-only prose in `modules/Session_*/*.typ`. The hook will remind you.
- After adding bullets, a table, or an `image()` inside a box.
- When the user reports a box "squashed", "cut off", "running off the page", or
  "overlapping the footer".

## When to skip

- The edit added/changed content **outside** any callout box (plain prose,
  `figure-box`, `two-column-content` — none of these use `breakable: false`).
- The edit only shortened box content or fixed a typo that cannot grow height.
- The edit is slide-only (`summary:` of a `content-block`) with no box change —
  that is `slide-fit-check`'s job, not this one.

When skipping, say so in one line ("skipping box-fit-check — edit is outside any
callout box") so the user knows you considered it.

## Why these boxes overflow (the mechanism)

`concept-box` is the base; `takeaways-box`/`definition-box`/`example-box` are
thin wrappers that set a preset title and colour. All four share:

```typst
block(breakable: false)[ #rect(stroke: 2pt + <colour>, inset: 1em)[ ...body... ] ]
```

When the body is taller than the available page:

1. `breakable: false` first tries to move the **whole** box to the next page.
2. If the box is taller than a *full* page, it cannot fit anywhere — Typst lays
   it out at full height anchored at the top of a fresh page. The **rect border
   stops at the bottom content margin**, but the body text continues past it,
   over the footer and off the page edge. No content is dropped; it is rendered
   past the boundary (detectable in the PDF stream, like slide overflow).

Border colours (the detection key), from `concept-box`:

| Box | `type` | Border colour |
| --- | --- | --- |
| `concept-box` info / `takeaways-box` | `info` | `#3b82f6` |
| `concept-box` warning | `warning` | `#f59e0b` |
| `concept-box` success / `example-box` | `success` | `#10b981` |
| `concept-box` note / `definition-box` | `note` | `#6b7280` |

## Workflow

### 1. Identify the session and build the document PDF

From the edited file path extract the session number
(`modules/Session_4/2_hedging.typ` → session 4), then build the **document**
(not the slides):

```bash
make build/Session_<N>_*/Session_<N>_document.pdf
```

If the build fails, stop and fix the build error first — overflow check is moot.

### 2. Scan every box for spill

Run this single script. It finds every callout box on every page by border
colour, and flags a box as **OVERFLOW** when its border is jammed against the
bottom content margin (the `breakable: false` block consumed a full page) *and*
text spills below the border within the box's column. A box that simply ends low
on a page but contains its body — or normal prose flowing after a box — does not
trip the check.

```bash
python3 - <<'PY'
import fitz, glob

SESSION = 4                                                  # ← set
PDF = glob.glob(f"build/Session_{SESSION}_*/Session_{SESSION}_document.pdf")[0]

# concept-box border colours (RGB 0..1) -> box family label
COLORS = {
    (0x3b/255, 0x82/255, 0xf6/255): "info / takeaways",
    (0xf5/255, 0x9e/255, 0x0b/255): "warning",
    (0x10/255, 0xb9/255, 0x81/255): "success / example",
    (0x6b/255, 0x72/255, 0x80/255): "note / definition",
}
BOTTOM_MARGIN = 72          # 1in document margin (Session_*_document.typ)
TOL = 2.0

def near(a, b, t=0.02):
    return a and all(abs(x - y) < t for x, y in zip(a, b))

def box_title(page, r):
    # The bold coloured title sits just inside the top-left of the rect.
    for b in page.get_text("rawdict")["blocks"]:
        for L in b.get("lines", []):
            for s in L.get("spans", []):
                bb = fitz.Rect(s["bbox"])
                if bb.y0 < r.y0 + 22 and bb.y0 > r.y0 - 2 and bb.x0 < r.x0 + 40:
                    txt = s.get("text", "").strip()
                    if txt:
                        return txt[:40]
    return "(untitled)"

doc = fitz.open(PDF)
flagged = []
for pno, page in enumerate(doc):
    H = page.rect.y1
    content_bot = H - BOTTOM_MARGIN
    spans = [fitz.Rect(s["bbox"])
             for b in page.get_text("rawdict")["blocks"]
             for L in b.get("lines", []) for s in L.get("spans", [])]
    for d in page.get_drawings():
        col = d.get("color")
        for c, label in COLORS.items():
            if near(col, c) and d.get("width") and abs(d["width"] - 2) < 0.5:
                r = d["rect"]
                jammed = r.y1 >= content_bot - TOL
                # text starting at/just below the border within the box column
                straddle = [s for s in spans
                            if s.y1 > r.y1 + 1 and s.x0 >= r.x0 - 2
                            and s.x1 <= r.x1 + 2 and s.y0 < r.y1 + 18]
                if jammed and straddle:
                    # measure full spill depth (all body text below the border)
                    deep = max((s.y1 for s in spans
                                if s.y1 > r.y1 and s.x0 >= r.x0 - 2
                                and s.x1 <= r.x1 + 2), default=r.y1)
                    flagged.append((pno + 1, label, box_title(page, r),
                                    r.y1, deep, H))

if not flagged:
    print("OK — every callout box contains its content.")
else:
    for pg, label, title, y1, deep, H in flagged:
        print(f"OVERFLOW  page {pg}  [{label}]  \"{title}\"")
        print(f"          border bottom y={y1:.0f} (page bottom margin), "
              f"content spills to y={deep:.0f} / page height {H:.0f}")
PY
```

### 3. (Optional) Visual confirmation

For a flagged box, render the page to confirm and to judge how much must be cut:

```bash
python3 - <<'PY'
import fitz, glob
PDF = glob.glob("build/Session_<N>_*/Session_<N>_document.pdf")[0]
doc = fitz.open(PDF)
for p in [<page>]:                       # 1-based, from the report
    doc[p - 1].get_pixmap(dpi=90).save(f"/tmp/boxfit_p{p}.png")
PY
```

Then `Read` the PNG.

### 4. Report and fix

Report one line per checked document:

```text
Session <N> document — OK   |   OVERFLOW: page <P>, "<title>"
```

When a box overflows, the box can never grow a page, so the fix is to reduce its
height or let it break:

- **Split the box** into two (or move the second half into a following box /
  plain prose). Best when the content is a long bullet list.
- **Shorten** the body — boxes are summaries; long exposition belongs in the
  surrounding `details:` prose, not inside a callout.
- **Move depth out of the box** — keep only the headline takeaways in
  `takeaways-box`; push detail to normal paragraphs.
- **(Submodule change, last resort)** make `concept-box` use
  `block(breakable: true)` so a long box can split across pages. This changes the
  visual contract (a box may straddle a page break) — only do this deliberately,
  and update `typst-dual-format/CLAUDE.md` if so. Do **not** silently flip it to
  paper over one long box.

If everything fits, say so in **one line**. Do not fabricate issues.

## Why programmatic, not visual-only

Like `slide-fit-check`, the off-page text coordinates are written into the PDF
stream verbatim, so a numerical comparison (border at the bottom margin + text
below the border) deterministically detects spill without relying on image
reading. Reserve PNG inspection for judging the fix or for borderline cases.

## Evolving this skill

- If `concept-box`'s colours change in the submodule, update the `COLORS` map.
- If a document driver uses a margin other than 1in, set `BOTTOM_MARGIN`
  accordingly (read it from `Session_*_document.typ`'s `#set page(margin: …)`).
- If a new overflow mode appears that the border-jammed + spill test misses, add
  a detection rule here next to the existing one.
