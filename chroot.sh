#!/usr/bin/env bash

whoami
ls -ld /dev
ls /dev/null -lia
mknod /dev/null c 1 3
chmod 666 /dev/null
apt-get update
apt-get install -y locales
locale-gen en_GB.UTF-8
dpkg-reconfigure -f noninteractive locales
apt-get install -y libdrm-dev libunwind-dev zlib1g-dev symlinks
symlinks -cr /lib /usr/lib
exit
