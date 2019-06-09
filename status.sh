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
    echo "Exiting, specified VM ${1} isn't within the configured number of VMs"
    exit 1
  fi
else
  START_COUNT=0
  END_COUNT=$((NODE_COUNT-1))
fi

for VM_NUM in $(seq "${START_COUNT}" "${END_COUNT}"); do
  if [ -e "${RUN_DIR}/vms/${VM_NUM}/pid" ]; then
    PID=$(cat "${RUN_DIR}/vms/${VM_NUM}/pid")
    if pgrep -q -F "${RUN_DIR}/vms/${VM_NUM}/pid" 2>/dev/null; then
      printf "* VM %s is running, PID: %s\n" "${VM_NUM}" "${PID}"
    else
      printf "* VM %s is stopped, ungraceful shutdown, PID: %s\n" "${VM_NUM}" "${PID}"
    fi
  else
    printf "* VM %s missing pid file, greacefully shutdown / never started\n" "${VM_NUM}"
  fi
done