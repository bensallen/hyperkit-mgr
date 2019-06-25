#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

if ! type realpath > /dev/null 2>&1; then
  echo "Exiting, requires realpath to be installed, eg. brew install coreutils"
  exit 1
fi

if ! type hyperkit > /dev/null 2>&1; then
  if [ ! -e /Applications/Docker.app//Contents/Resources/bin/com.docker.hyperkit ]; then
    echo "Exiting, requires hyperkit to be installed, eg. brew install hyperkit"
    exit 1
  fi
fi

if ! type qemu-img > /dev/null 2>&1; then
  echo "Exiting, requires qemu-img to be installed, eg. brew install qemu"
  exit 1
fi

SCRIPTPATH=$(realpath "$(dirname "$0")")

if [ -e "${SCRIPTPATH}/config" ]; then
  # shellcheck source=config
  . "${SCRIPTPATH}/config"
fi

# Path for VM artifacts
RUN_DIR="${RUN_DIR:-${SCRIPTPATH}/.run}"

# Number of VMs
NODE_COUNT=${NODE_COUNT:-3}

DISTRO=${DISTRO:-rancheros}

NODE_CPUS=${NODE_CPUS:-1}
NODE_MEM=${NODE_MEM:-2048}
NODE_HDDSIZE=${NODE_HDDSIZE:-16G}

BRIDGE_DEV=${BRIDGE_DEV:-bridge1}
BRIDGE_IP=${BRIDGE_IP:-192.168.99.1/24}

# What tap device to start with, eg. tap<N>, tap<N+1>, ...
TAP_DEV_INDEX=${TAP_DEV_INDEX:-0}

if [ ! -e "/dev/tap${TAP_DEV_INDEX}" ]; then
  echo "Exiting, no tap devices found. Is the tuntap driver installed, eg. brew cask install tuntap?"
  exit 1
fi

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

if ! ifconfig "${BRIDGE_DEV}" >/dev/null 2>&1; then
  echo "Exiting, bridge interface ${BRIDGE_DEV} doesn't exist, eg. System Preferences -> Network -> Manage Virtual Interfaces"
  exit 1
fi




if [ -e "${SCRIPTPATH}/distro.d/${DISTRO}" ]; then
  # shellcheck source=distro.d/rancheros
  . "${SCRIPTPATH}/distro.d/${DISTRO}"
else 
  echo "Exiting, distro config file: ${SCRIPTPATH}/distro.d/${DISTRO} does not exist"
  exit 1
fi

if [ ! -f "${RUN_DIR}/.ssh/hyperkit.pub" ]; then
  mkdir -p "${RUN_DIR}/.ssh"
  ssh-keygen -t ed25519 -N "" -C "" -f "${RUN_DIR}/.ssh/hyperkit" >/dev/null
fi

pre

# Skip VMs that are already running
VMS=()
for VM_NUM in $(seq "${START_COUNT}" "${END_COUNT}"); do
  if [ -e "${RUN_DIR}/vms/${VM_NUM}/pid" ]; then
    PID=$(cat "${RUN_DIR}/vms/${VM_NUM}/pid")
    if pgrep -q -F "${RUN_DIR}/vms/${VM_NUM}/pid"; then
      echo -e "* Skipping vm${VM_NUM}, existing proccess: ${PID}"
      continue
    fi
  fi
  VMS+=("${VM_NUM}")
done

# Exit if no VMs to work on
if [ ${#VMS[@]} -eq 0 ]; then
  exit 0
fi

# Workaround macOS dropping all members of the TAP bridge when a VM with vmnet is brought up
EXT_BRIDGE_MEMBERS=$( (ifconfig ${BRIDGE_DEV} | grep member: | cut -f 2 -d " ") || true)
if [ -n "${EXT_BRIDGE_MEMBERS}" ]; then
  for EDEV in ${EXT_BRIDGE_MEMBERS}; do
    # Ignore tap devices that are for VMs we're working with
    if [ "${EDEV:0:3}" == "tap" ] && printf '%s\n' "${VMS[@]}" | grep -q -w "${EDEV#tap}"; then
      continue
    fi
    TAP_LIST+=(addm "${EDEV}")
  done
fi

for VM_NUM in "${VMS[@]}"; do

  mkdir -p "${RUN_DIR}/vms/${VM_NUM}"

  # shellcheck disable=SC2034
  NETADDR="$(echo $BRIDGE_IP | cut -d. -f1-3)"
  # shellcheck disable=SC2034
  CIDR=$(echo $BRIDGE_IP | cut -d/ -f2)
  TAP="tap$((TAP_DEV_INDEX + VM_NUM))"

  CMDLINE=$(cmdline)

  pre-vm

  printf "* Booting VM %s ...\n" "$VM_NUM"

  "${SCRIPTPATH}/hyperkit.sh" "${RUN_DIR}/vms/${VM_NUM}" "${KERNEL_PATH}" "${INITRD_PATH}" "${CMDLINE}" "${TAP}" "${NODE_CPUS}" "${NODE_MEM}" "${NODE_HDDSIZE}"

  # Change permissions of the VM files and TTY from root to the user
  until [ -e "${RUN_DIR}/vms/${VM_NUM}/tty" ] && [ -e "${RUN_DIR}/vms/${VM_NUM}/pid" ]; do
    sleep 1
  done
  sudo chown -h "$USER" "${RUN_DIR}/vms/${VM_NUM}/tty"
  sudo chown "$USER" "${RUN_DIR}/vms/${VM_NUM}"/*

  until ifconfig "${TAP}" >/dev/null 2>&1; do
    echo -e "  waiting for ${TAP} interface to come up...\n"
    sleep 1
  done
  TAP_LIST+=(addm "${TAP}")

  post-vm
done

# This code does not work. It appears when vmnet is used with the above VMs
# and macOS brings up bridge100 (vmnet), the bridge created here is lost.
# No obvious way to add the bridge interface presistently via macOS tools 
# like networksetup, so just have to create the bridge via the GUI:
# System Preferences -> Netework -> Manage Virtual Interfaces
#
#if ! ifconfig "${BRIDGE_DEV}"; then
#  ifconfig "${BRIDGE_DEV}" create
#  until ifconfig "${BRIDGE_DEV}"; do
#    echo "waiting for ${BRIDGE_DEVTAP} to come up..."; sleep 5
#  done
#  ifconfig "${BRIDGE_DEV}" "${BRIDGE_IP}"
#  ifconfig "${BRIDGE_DEV}" up
#fi

# Add tap interfaces to bridge
if [ -n "${TAP_LIST:-}" ] && [ ${#TAP_LIST[@]} -ge 2 ]; then
  printf "* Attaching tap interface(s) to %s ...\n" "${BRIDGE_DEV}"
  sudo ifconfig ${BRIDGE_DEV} "${TAP_LIST[@]}"
fi

echo "* Console TTYs (escape via Ctrl-a k):"
for VM in "${VMS[@]}"; do
  echo "  - screen $RUN_DIR/vms/$VM/tty"
done

post