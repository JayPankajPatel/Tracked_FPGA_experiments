#!/usr/bin/env bash
# Run a Vivado Tcl script in batch mode against the hw_server tunnel.
# Usage: hw_session.sh <script.tcl> [tclargs...]
# Env:   VIVADO_SETTINGS (default ~/Programs/AMD/Vivado/2024.1/settings64.sh)
#        HW_URL          (default localhost:3121)
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: ${0##*/} <script.tcl> [tclargs...]" >&2; exit 2; }
script=$1; shift

settings=${VIVADO_SETTINGS:-$HOME/Programs/AMD/Vivado/2024.1/settings64.sh}
export HW_URL=${HW_URL:-localhost:3121}
port=${HW_URL##*:}

# shellcheck disable=SC1090
source "$settings"

if ! ss -ltn | grep -q "127.0.0.1:${port}\b"; then
  echo "ERROR: nothing listening on ${HW_URL}. Start the tunnel on the hardware" >&2
  echo "       host: ~/Programs/AMD/remote_fpga_jtag/start_hw_tunnel.sh <user@this-host>" >&2
  exit 3
fi

exec vivado -mode batch -nojournal -nolog -source "$script" -tclargs "$@"
