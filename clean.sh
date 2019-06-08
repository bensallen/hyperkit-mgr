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

# Path to create VM artifacts
RUN_DIR="${RUN_DIR:-${SCRIPTPATH}/.run}"

if [ -e "${SCRIPTPATH}/distro.d/${DISTRO}" ]; then
    # shellcheck source=distro.d/rancheros
  . "${SCRIPTPATH}/distro.d/${DISTRO}"
else 
  echo "Exiting, distro config file: ${SCRIPTPATH}/distro.d/${DISTRO} does not exist"
  exit 1
fi

rm -rf "${RUN_DIR}/vms" "${RUN_DIR}/.ssh"

# Run distro clean()
clean