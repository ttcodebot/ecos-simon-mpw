#!/usr/bin/env python3
"""Patch the ECC (OpenECOS Chip Compiler) Yosys LEC script so that sequential
designs with hidden state can be proven.

The stock `run_lec.tcl` (ecc v0.1.0-alpha.12) runs `opt_clean -purge`, which
deletes every internal net name before `equiv_make`. Only the top-level ports
remain paired, so `equiv_induct` has no register pairing and cannot prove any
output whose value depends on state that is not observable at the ports (for
example a prescaler counter). The result is "unproven" even though the
netlists are equivalent.

This patch keeps internal names and passes `equiv_make` a blacklist of every
golden-netlist wire that is neither a port nor a flip-flop Q output, so the
equivalence points are exactly {ports, register outputs}. Verified on the
Simon Says design: 299/299 equivalence points proven (stock script: 15
unproven). The patch is idempotent and refuses to touch an unknown script.
"""
import os
import re
import sys
from pathlib import Path

MARKER = "# --- patched by patch_ecc_lec.py (register-output equivalence pairing) ---"

TCL_HELPER = r'''
proc generate_ff_blacklist {golden_file out_file} {
    # Keep ports and flip-flop Q outputs as equivalence points; blacklist all
    # other named wires of the golden netlist (intermediate logic nets whose
    # names collide with differently-structured nets in the gate netlist).
    # Processed line by line: Tcl's regexp -all -line is quadratic on big files.
    set fh [open $golden_file r]
    set lines [split [read $fh] "\n"]
    close $fh
    set keep [dict create]
    set wires [list]
    set in_ports 0
    foreach line $lines {
        if {$in_ports} {
            foreach p [split $line ","] {
                set p [string trim [string map {");" "" ")" ""} $p]]
                if {$p ne ""} { dict set keep $p 1 }
            }
            if {[string first ")" $line] >= 0} { set in_ports 0 }
            continue
        }
        if {[regexp {^\s*module\s+\S+\s*\((.*)$} $line -> rest]} {
            foreach p [split $rest ","] {
                set p [string trim [string map {");" "" ")" ""} $p]]
                if {$p ne ""} { dict set keep $p 1 }
            }
            if {[string first ")" $rest] < 0} { set in_ports 1 }
            continue
        }
        if {[regexp {\.Q\(\s*(\\?[^\s\)]+)\s*\)} $line -> name]} {
            dict set keep $name 1
            continue
        }
        if {[regexp {^\s*wire\s+(?:\[[^\]]+\]\s*)?(\\?[^\s;]+)\s*;} $line -> name]} {
            lappend wires $name
        }
    }
    set out [open $out_file w]
    foreach name $wires {
        if {![dict exists $keep $name]} {
            puts $out [string trimleft $name "\\"]
        }
    }
    close $out
}
'''


def find_script() -> Path:
    root = Path(os.environ.get("ECC_DATA_ROOT", Path.home() / ".local/share/ecc"))
    candidates = sorted(root.glob("v*/_internal/chipcompiler/tools/yosys_lec/scripts/run_lec.tcl"))
    if not candidates:
        sys.exit(f"run_lec.tcl not found under {root}")
    return candidates[-1]


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_script()
    text = path.read_text()
    if MARKER in text:
        print(f"already patched: {path}")
        return 0
    old_normalize = "    yosys splitnets -ports -format _\n    yosys opt_clean -purge\n"
    old_equiv = ("    if {$blacklist_file ne \"\"} {\n"
                 "        require_file \"LEC blacklist\" $blacklist_file\n"
                 "        yosys equiv_make -blacklist $blacklist_file gold gate equiv\n"
                 "    } else {\n"
                 "        yosys equiv_make gold gate equiv\n"
                 "    }\n")
    if old_normalize not in text or old_equiv not in text:
        sys.exit(f"unexpected run_lec.tcl content in {path}; refusing to patch")
    text = text.replace(old_normalize, "    yosys splitnets -ports -format _\n    yosys opt_clean\n")
    new_equiv = ("    if {$blacklist_file ne \"\"} {\n"
                 "        require_file \"LEC blacklist\" $blacklist_file\n"
                 "    } else {\n"
                 "        global golden_file report_dir\n"
                 "        set blacklist_file [file join $report_dir ff_pairing_blacklist.txt]\n"
                 "        generate_ff_blacklist $golden_file $blacklist_file\n"
                 "    }\n"
                 "    yosys equiv_make -blacklist $blacklist_file gold gate equiv\n")
    text = text.replace(old_equiv, new_equiv)
    text = text.replace("proc run_equivalence {} {", MARKER + TCL_HELPER + "\nproc run_equivalence {} {", 1)
    backup = path.with_suffix(".tcl.orig")
    if not backup.exists():
        backup.write_text(path.read_text())
    path.write_text(text)
    print(f"patched: {path} (backup: {backup})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
