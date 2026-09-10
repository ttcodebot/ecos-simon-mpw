#!/usr/bin/env bash
# Print ICS55 PDK paths from the ecc installation (or CHIPCOMPILER_ICS55_PDK_ROOT).
set -euo pipefail
root="${CHIPCOMPILER_ICS55_PDK_ROOT:-}"
if [[ -z "$root" ]]; then
  root=$(ls -d "$HOME"/.local/share/ecc/pdks/icsprout55/v* 2>/dev/null | sort -V | tail -1 || true)
fi
[[ -d "$root" ]] || { echo "ICS55 PDK not found; run scripts/install_ecc.sh" >&2; exit 1; }
case "${1:-root}" in
  root) echo "$root" ;;
  stdcell) echo "$root/IP/STD_cell/ics55_LLSC_H7C_V1p10C100" ;;
  *) echo "unknown query: $1" >&2; exit 2 ;;
esac
