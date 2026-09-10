#!/usr/bin/env bash
# Install the OpenECOS Chip Compiler CLI together with the OSS CAD Suite
# (Yosys), the ICS55 PDK and ecc-sizer into ~/.local (about 6 GB).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if command -v ecc >/dev/null && ecc doctor --plain >/dev/null 2>&1; then
  echo "ecc already installed: $(ecc --version)"
  python3 "$SCRIPT_DIR/patch_ecc_lec.py"
  exit 0
fi
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh -o /tmp/ecc-installer.sh
sh /tmp/ecc-installer.sh --with-toolchain --download-source "${ECC_DOWNLOAD_SOURCE:-auto}"
python3 "$SCRIPT_DIR/patch_ecc_lec.py"
ecc version
ecc doctor --plain
