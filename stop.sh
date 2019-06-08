#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

if ! type realpath > /dev/null 2>&1; then
  echo "Requires realpath to be installed, which is part of coreutils"
  exit 1
fi

SCRIPTPATH=$(realpath "$(dirname "$0")")

if [ -e "${SCRIPTPATH}/config" ]; then
  # shellcheck source=config
  . "${SCRIPTPATH}/config"
fi

# Number of VMs
NODE_COUNT=${NODE_COUNT:-3}

# Path to VM artifacts
RUN_DIR="${RUN_DIR:-${SCRIPTPATH}/.run}"

# First argument can be the VM index number to work with
if [ -n "${1:-}" ]; then
  if [ "${1}" -ge 0 ] && [ "${1}" -lt ${NODE_COUNT} ]; then
    START_COUNT=${1}
    END_COUNT=${1}
  else
    echo "Specified VM ${1} isn't within the configured number of VMs"
    exit 1
  fi
else
  START_COUNT=0
  END_COUNT=$((NODE_COUNT-1))
fi

SIGNAL=${2:-15}

for i in $(seq "${START_COUNT}" "${END_COUNT}"); do
  if [ -e "$RUN_DIR/vms/$i/pid" ]; then
    PID="$(cat "$RUN_DIR/vms/$i/pid")" 
    kill -"${SIGNAL}" "$PID" || echo "Signal $SIGNAL to $PID failed..."
  fi
done