# ECC Yosys LEC: unproven results for designs with hidden state

**Tool:** OpenECOS Chip Compiler `ecc` v0.1.0-alpha.12 (`ecc_tools` 0.1.0a13,
yosys 0.68+132 from the OSS CAD Suite 2026-08-27), ICS55 PDK v1.10.102.

## Symptom

The `lec` step (`chipcompiler/tools/yosys_lec/scripts/run_lec.tcl`) reports
`unproven` for every registered output of a design whose internal state is not
observable at the top-level ports, and the `rtl2gds` flow stops:

```
Found 132 $equiv cells in equiv:
  Of those cells 117 are proven and 15 are unproven.
  Unproven $equiv ... \io_out_8_gold \io_out_8_gate
  ...
```

Minimal reproducer: a 12-bit prescaler with a registered `tick` output
(`simon_tick_gen.v` in this repository), `preset = "synthesis_lec"`:

```
  Of those cells 0 are proven and 1 are unproven.
  Unproven $equiv ... \tick_gold \tick_gate
```

whereas a 32-bit LFSR whose whole state is an output (`galois_lfsr.v`) proves.

## Cause

`normalize_design` runs `opt_clean -purge`, which removes every internal net
name. `equiv_make` therefore only creates `$equiv` cells for the top-level
ports, and `equiv_simple` / `equiv_induct` have no register pairing: the
induction hypothesis is "outputs equal", which does not imply "state equal", so
any output that depends on hidden state is unprovable. The netlists themselves
are equivalent: pairing the flip-flop outputs proves all 299 equivalence points
for the Simon Says design (`scripts/patch_ecc_lec.py`).

Simply dropping `-purge` is not enough: the golden netlist also names
intermediate nets (e.g. `<reg>_reg_p_D`) that exist under the same name in the
mapped netlist with different logic (synchronous reset folded into the D cone),
and those false pairs poison the induction.

## Fix used here

`scripts/patch_ecc_lec.py` (applied by `scripts/install_ecc.sh`):

1. `opt_clean -purge` → `opt_clean` in `normalize_design`;
2. before `equiv_make`, generate a blacklist of every golden-netlist wire that is
   neither a port nor a flip-flop `Q` output and pass it with
   `equiv_make -blacklist`.

Result on the Simon Says design: `Found 299 $equiv cells ... 299 are proven ...
Equivalence successfully proven!` for both the synthesis-level and the
post-route LEC. Suggested upstream change: the same two edits in
`run_lec.tcl`, or an `equiv_make -blacklist` generated from the golden
netlist's register outputs.
