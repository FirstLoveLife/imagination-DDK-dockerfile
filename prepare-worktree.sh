#!/usr/bin/env bash
# Author: lchen@ambarella.com
#
RED='\033[0;31m'
NC='\033[0m' # No Color

DEST_KERNEL_DIR=kernel-src
KERNEL_BRANCH=linux-5.15-ambarella-main
CHIP=cv3ad685
KERNELCONF=arch/arm64/configs/ambarella_${CHIP}_defconfig

if [[ ! -d "rogue_km" || ! -d "rogue" || ! -d $DEST_KERNEL_DIR ]]; then
  read -p "Enter user(e.g., lchen): " user
fi

KERNEL_URL=ssh://${user}@ambsh-git.ambarella.com:29418/kernel/git/stable/linux-stable.git

if [ -d "$DEST_KERNEL_DIR" ]; then
  echo "INFO: $DEST_KERNEL_DIR exist already, just skip..."
else
  git clone --progress ${KERNEL_URL} --branch ${KERNEL_BRANCH} --single-branch ${DEST_KERNEL_DIR}
  if [[ -z "$KERNELCONF" ]]; then 
	echo "ERROR: $KERNELCONF is not available"
	exit 1
  fi
  set -x
  rm -rf ${DEST_KERNEL_DIR}/.git
  cp ${DEST_KERNEL_DIR}/${KERNELCONF} ${DEST_KERNEL_DIR}/.config
  set +x
fi

# FIXME: git fetch + git worktree fail somehow, use single branch as workaround.
if [[ ! -d "rogue_km" || ! -d "rogue" ]]; then
  read -p "Enter sdk version(e.g., 23.1, 23.2, 23.2-ws): " version
  if [ ! -d "rogue_km" ]; then
    set -x
    git clone --progress -b ${version}/rogue_km --single-branch ssh://${user}@ambsh-git.ambarella.com:29418/ambarella/kernel-development.git rogue_km
    set +x
  fi
  if [ ! -d "rogue" ]; then
    set -x
    git clone --progress -b ${version}/rogue_um --single-branch ssh://${user}@ambsh-git.ambarella.com:29418/ambarella/kernel-development.git rogue
    set +x
    read -p "Do you want to use http proxy when download llvm, if yes, please enter IP:port, e.g., 127.0.0.1:7890, otherwise, live it empty and just enter:" proxy
    if [ -n "${proxy}" ]; then
      sed -i "4i export http_proxy=${proxy} https_proxy=${proxy}" rogue/build/linux/tools/prepare-llvm.sh
    fi
    # CRLF issue
    if [ -f ${version}/spv.patch ]; then
      cp ${version}/spv.patch rogue/compiler/llvmufgen/patches/
    fi
  fi
else
  echo "rogue_km and rogue exist already, just skip..."
fi

echo "INFO: prepare successfully"
