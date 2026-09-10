#!/usr/bin/env python3
"""Compose docs/results.md from dist/summary.md, a variant blurb and the shared pricing notes.

usage: results_md.py <variant-title> <blurb-file> <dist/summary.md> <pricing.md> <out.md>
"""
import sys
from pathlib import Path

title, blurb, summary, pricing, out = sys.argv[1:6]
text = "\n".join([
    f"# {title} — hardening results and cost estimate",
    "",
    Path(blurb).read_text().strip(),
    "",
    Path(summary).read_text().strip(),
    "",
    f"![layout]({Path(out).stem.replace('results', '') and ''}{Path(summary).parent.name and ''}{layout})" if (layout := (sys.argv[6] if len(sys.argv) > 6 else "")) else "",
    "",
    Path(pricing).read_text().strip(),
    "",
])
Path(out).write_text(text)
print(out)
