#!/usr/bin/env python3
"""Summarise an ECC workspace (design summary + params) into JSON and Markdown."""
import json
import re
import sys
from pathlib import Path


def parse_summary(text: str) -> dict:
    metrics = {}
    patterns = {
        "die_area_um2": r"Die Area\s+([\d.,]+) um",
        "core_area_um2": r"Core Area\s+([\d.,]+) um",
        "core_utilization_pct": r"Core Utilization\s+([\d.]+) %",
        "stdcell_area_um2": r"Standard Cell Area\s+([\d.,]+) um",
        "instances": r"Total Instances\s+([\d,]+)",
        "sequential_cells": r"Sequential / Comb\. Cells\s+([\d,]+) /",
        "combinational_cells": r"Sequential / Comb\. Cells\s+[\d,]+ / ([\d,]+)",
        "io_pins": r"IO Pins\s+([\d,]+)",
        "target_clock_period_ns": r"Target Clock Period\s+([\d.]+) ns",
        "fmax_mhz": r"Achieved Fmax\s+([\d.]+) MHz",
        "setup_wns_ns": r"Setup Slack \(WNS / TNS\)\s+(-?[\d.]+) ns",
        "hold_wns_ns": r"Hold Slack \(WNS / TNS\)\s+(-?[\d.]+) ns",
        "routed_wirelength_um": r"Routed Wirelength\s+([\d.,]+) um",
        "total_power_mw": r"Total Power\s+([\d.]+) mW",
        "drc_status": r"DRC Status\s+(\S+(?: \(\d+ violations\))?)",
        "lvs_status": r"LVS Status\s+(\S+(?: \(\S+\))?)",
        "runtime": r"Total Runtime\s+([\dhms ]+?)\s{2,}",
    }
    for key, pat in patterns.items():
        m = re.search(pat, text)
        if m:
            value = m.group(1).strip()
            if key not in ("drc_status", "lvs_status", "runtime"):
                try:
                    value = float(value.replace(",", ""))
                    if key in ("instances", "sequential_cells", "combinational_cells", "io_pins"):
                        value = int(value)
                except ValueError:
                    pass
            metrics[key] = value
    corners = re.findall(r"^\s+(\S+/\S+)\s+(-?[\d.]+) ns\s+(-?[\d.]+) ns\s+(-?[\d.]+) ns\s+(-?[\d.]+) ns\s+(PASS|FAIL)", text, re.M)
    if corners:
        metrics["timing_corners"] = [
            {"corner": c, "setup_wns_ns": float(sw), "setup_tns_ns": float(st),
             "hold_wns_ns": float(hw), "hold_tns_ns": float(ht), "status": s}
            for c, sw, st, hw, ht, s in corners
        ]
    return metrics


def parse_die(params_text: str) -> dict:
    die = {}
    for key in ("die_width", "die_height", "core_width", "core_height", "core_utilization"):
        m = re.search(rf"^{key}\s*=\s*([\d.]+)", params_text, re.M)
        if m:
            die[key] = float(m.group(1))
    return die


def main() -> int:
    ws, design, out_json, out_md = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4])
    summary_txt = (ws / "signoff" / f"{design}_design_summary.txt").read_text()
    metrics = parse_summary(summary_txt)
    params = ws / "home" / "params.toml"
    if params.exists():
        metrics["die"] = parse_die(params.read_text())
    fp = ws / "Floorplan_ecc" / "analysis" / "qor_metrics.json"
    if fp.exists() and not metrics.get("die"):
        try:
            fpm = {m["id"]: m.get("value") for m in json.loads(fp.read_text()).get("metrics", []) if isinstance(m, dict)}
            metrics["die"] = {k: float(fpm[k]) for k in ("die_width", "die_height", "core_width", "core_height") if k in fpm}
        except (ValueError, TypeError):
            pass
    qor = ws / "signoff" / f"{design}_qor_report.txt"
    if qor.exists():
        m = re.search(r"Overall\s*(?:QoR\s*)?Score[^\d]*([\d.]+)", qor.read_text(), re.I)
        if m:
            metrics["qor_score"] = float(m.group(1))
    metrics["design"] = design
    out_json.write_text(json.dumps(metrics, indent=2) + "\n")

    def fmt(key, unit=""):
        v = metrics.get(key)
        if v is None:
            return "—"
        if isinstance(v, float):
            v = f"{v:,.2f}"
        elif isinstance(v, int):
            v = f"{v:,}"
        return f"{v}{unit}"

    die = metrics.get("die", {})
    die_dims = "—"
    if "die_width" in die and "die_height" in die:
        die_dims = f"{die['die_width']:.2f} × {die['die_height']:.2f} µm"
    lines = [
        f"## {design} — ICS55 hardening report",
        "",
        "| Metric | Value |",
        "| --- | --- |",
        f"| Die size | {die_dims} |",
        f"| Die area | {fmt('die_area_um2', ' µm²')} |",
        f"| Core area | {fmt('core_area_um2', ' µm²')} |",
        f"| Core utilization | {fmt('core_utilization_pct', ' %')} |",
        f"| Standard cell area | {fmt('stdcell_area_um2', ' µm²')} |",
        f"| Instances | {fmt('instances')} |",
        f"| Flip-flops / combinational | {fmt('sequential_cells')} / {fmt('combinational_cells')} |",
        f"| IO pins | {fmt('io_pins')} |",
        f"| Target clock | {fmt('target_clock_period_ns', ' ns')} |",
        f"| Achieved Fmax | {fmt('fmax_mhz', ' MHz')} |",
        f"| Setup / hold WNS | {fmt('setup_wns_ns', ' ns')} / {fmt('hold_wns_ns', ' ns')} |",
        f"| Routed wirelength | {fmt('routed_wirelength_um', ' µm')} |",
        f"| Total power (typ) | {fmt('total_power_mw', ' mW')} |",
        f"| DRC | {metrics.get('drc_status', '—')} |",
        f"| LVS | {metrics.get('lvs_status', '—')} |",
        f"| QoR score | {fmt('qor_score')} |",
        f"| Flow runtime | {metrics.get('runtime', '—')} |",
        "",
    ]
    if "timing_corners" in metrics:
        lines += ["| Corner | Setup WNS | Hold WNS | Status |", "| --- | --- | --- | --- |"]
        for c in metrics["timing_corners"]:
            lines.append(f"| {c['corner']} | {c['setup_wns_ns']} ns | {c['hold_wns_ns']} ns | {c['status']} |")
        lines.append("")
    out_md.write_text("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
