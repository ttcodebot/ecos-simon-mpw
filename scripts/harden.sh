#!/usr/bin/env bash
# Run the OpenECOS Chip Compiler (ECC) RTL-to-GDS flow on the ICS55 PDK and
# collect the tapeout deliverables under dist/.
#
# Usage: scripts/harden.sh [--skip-run]
#
# Requires the `ecc` CLI installed with `--with-toolchain` (see
# scripts/install_ecc.sh). The project configuration lives in harden/ecc.toml;
# RTL sources are copied into harden/rtl/ from the locations listed in
# harden/sources.txt (paths relative to the repository root).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HARDEN_DIR="$ROOT/harden"
DIST="$ROOT/dist"
export PATH="$HOME/.local/bin:$PATH"

SKIP_RUN=0
for arg in "$@"; do
  case "$arg" in
    --skip-run) SKIP_RUN=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v ecc >/dev/null || { echo "ERROR: ecc not found; run scripts/install_ecc.sh" >&2; exit 127; }

design=$(python3 - "$HARDEN_DIR/ecc.toml" <<'PY'
import sys, tomllib
print(tomllib.load(open(sys.argv[1], "rb"))["design"]["name"])
PY
)

# 1. Stage the RTL sources
rm -rf "$HARDEN_DIR/rtl"
mkdir -p "$HARDEN_DIR/rtl"
: > "$HARDEN_DIR/rtl/filelist.f"
while IFS= read -r src; do
  [[ -z "$src" || "$src" == \#* ]] && continue
  cp "$ROOT/$src" "$HARDEN_DIR/rtl/"
  basename "$src" >> "$HARDEN_DIR/rtl/filelist.f"
done < "$HARDEN_DIR/sources.txt"

cd "$HARDEN_DIR"
# optional environment for the flow tools (e.g. YOSYS_SYNTH_STRATEGY)
if [[ -f "$HARDEN_DIR/harden.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$HARDEN_DIR/harden.env"
  set +a
fi
if [[ "$SKIP_RUN" == 0 ]]; then
  # a stale workspace manifest from an earlier run makes `ecc check` crash
  rm -rf default project.json
fi
ecc doctor --plain || true
ecc check --plain

# 2. Run the full rtl2gds flow (synthesis -> LEC -> floorplan -> ... -> harden)
if [[ "$SKIP_RUN" == 0 ]]; then
  ecc run --preset rtl2gds --plain
fi
ecc status --plain | tee "$HARDEN_DIR/status.txt"
if grep -q "status=failed\|status=incomplete\|status=unstart" "$HARDEN_DIR/status.txt"; then
  echo "ERROR: ECC flow did not complete; see ecc status / ecc log" >&2
  exit 1
fi

# 3. Reports and signoff package
mkdir -p "$DIST"
ecc signoff inspect --plain | tee "$DIST/signoff_inspect.txt"
ecc report summary --plain
ecc report qor --plain
ecc report checklist --plain
ecc signoff export -o "$DIST/${design}_signoff_package.tar.gz" --plain

# 4. Deliverables
ws="$HARDEN_DIR/default"
gunzip -c "$ws/drc_ecc/output/${design}_drc.def.gz" > "$DIST/${design}.def"
gunzip -c "$ws/drc_ecc/output/${design}_drc.v.gz" > "$DIST/${design}.v"
# full layout GDS (all standard-cell geometry, fillers, PDN) = the DRC-step
# output; the Harden-step GDS is only the abstract (pins + obstruction)
cp "$ws/drc_ecc/output/${design}_drc.gds" "$DIST/${design}.gds"
cp "$ws/Harden_ecc/output/${design}_Harden.gds" "$DIST/${design}_harden_abstract.gds"
cp "$ws/Harden_ecc/output/${design}_Harden.lef" "$DIST/${design}.lef"
cp "$ws/Harden_ecc/output/${design}_Harden.lib" "$DIST/${design}.lib"
cp "$ws/Harden_ecc/output/${design}_Harden.png" "$DIST/${design}.png"
cp "$ws/signoff/${design}_design_summary.txt" "$ws/signoff/${design}_qor_report.txt" \
   "$ws/signoff/checklist_report.txt" "$DIST/"
cp "$ws/home/params.toml" "$DIST/ecc_params.toml"
gunzip -c "$ws/Synthesis_yosys/output/${design}_Synthesis.v.gz" > "$DIST/${design}_synthesis.v"

python3 "$ROOT/scripts/summarize.py" "$ws" "$design" "$DIST/summary.json" "$DIST/summary.md"
cat "$DIST/summary.md"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$DIST/summary.md" >> "$GITHUB_STEP_SUMMARY"
fi
echo "Deliverables written to $DIST"
ls -la "$DIST"
