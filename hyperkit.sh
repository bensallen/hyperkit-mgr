#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

VMDIR="${1}"
KERNEL="${2:-vmlinuz}"
INITRD="${3:-initrd}"
CMDLINE="${4:-earlyprintk=serial console=ttyS0}"
TAPDEV="${5:-tap0}"
CPUCOUNT="${6:-2}"
MEMSIZE="${7:-2G}"
HDDSIZE="${8:-16G}"

HYPERKIT=hyperkit
if ! type "${HYPERKIT}" > /dev/null 2>&1; then
  if [ ! -e /Applications/Docker.app//Contents/Resources/bin/com.docker.hyperkit ]; then
    echo "Requires hyperkit to be installed, eg. brew install hyperkit"
    exit 1
  fi
  HYPERKIT=/Applications/Docker.app//Contents/Resources/bin/com.docker.hyperkit
fi

if ! type qemu-img > /dev/null 2>&1; then
  echo "Requires qemu-img to be installed, eg. brew install qemu"
  exit 1
fi

if ! type realpath > /dev/null 2>&1; then
  echo "Requires realpath to be installed, eg. brew install coreutils"
  exit 1
fi


if [ -z "${VMDIR}" ] || [ ! -d "${VMDIR}" ]; then
  echo "VMDIR via \$1 needs to be specified and needs to already exist"
  exit 1
else
  VMDIR="$(realpath "${VMDIR}")"
fi

if [ ! -e "/dev/${TAPDEV}" ]; then
  echo "/dev/${TAPDEV} does not exist"
  exit 1
fi

# Check if there's an existing pid file and if so if the process is stil running.
# Hyperkit expects the pid file not to already exist.
if [ -e "${VMDIR}/pid" ]; then
  PID=$(cat "${VMDIR}/pid")
  if kill -0 "$PID"; then
    echo "Exiting, found pidfile with running proccess $PID"
    exit 1
  else
    rm -f "${VMDIR}/pid"
  fi
fi

if [ ! -e "${VMDIR}/hdd.qcow2" ]; then
  qemu-img create -f qcow2 -o lazy_refcounts=on,preallocation=metadata "${VMDIR}/hdd.qcow2" "${HDDSIZE}"
fi

if [ ! -e "${VMDIR}/uuid" ]; then
  uuidgen > "${VMDIR}/uuid"
fi

if [ ! -e "${VMDIR}/mac-eth1" ]; then
  # Using QEMU's OUI for a lack of better option.
  echo "52:54:00:$(dd if=/dev/urandom bs=512 count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\).*$/\1:\2:\3/')" > "${VMDIR}/mac-eth1"
fi

MEM=("-m" "${MEMSIZE}")
SMP=("-c" "${CPUCOUNT}")
ACPI="-A"
PID=("-F" "${VMDIR}/pid")
PCI_DEV=("-s 0:0,hostbridge" "-s" "31,lpc")
RND=("-s" "4,virtio-rnd")
UUID=("-U" "$(cat "${VMDIR}/uuid")")

# Automatically pick a /dev/ttysNN device to use, and symlink it to path $PWD/tty, plus log output to Apple System Logger (asl). Open console via "screen $PWD/tty"
LPC_DEV=("-l" "com1,autopty=$VMDIR/tty,asl")

# eth0, using vmnet. MAC addresses are derived from UUID.
ETH0=("-s" "2:0,virtio-net")

# eth1, use a tap device instead of vmnet. Requires: brew cask install tuntap, and creating bridge interface and ifconfig bridge0 addm tap0
ETH1=("-s" "2:1,virtio-tap,${TAPDEV},mac=$(cat "${VMDIR}/mac-eth1")")

# /dev/vda
IMG_HDD=("-s" "3,virtio-blk,file://${VMDIR}/hdd.qcow2,format=qcow")

$HYPERKIT "${UUID[@]}" "$ACPI" "${PID[@]}" "${MEM[@]}" "${SMP[@]}" "${PCI_DEV[@]}" "${LPC_DEV[@]}" "${ETH0[@]}" "${ETH1[@]}" "${IMG_HDD[@]}" "${RND[@]}" -f kexec,"$KERNEL","$INITRD","$CMDLINE" > "${VMDIR}/log" 2>&1 &

exit $?