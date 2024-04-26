#FROM docker.io/ustclug/ubuntu:22.04
FROM docker.io/ubuntu:22.04
LABEL maintainer="lchen@ambarella.com"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ='Asia/Shanghai'
RUN apt-get update -y \
	&& apt-get -y dist-upgrade \
	&&  apt-get install -y bison flex gawk gcc g++ libclang1-14 llvm make ninja-build m4 meson patch pkg-config python-is-python3 python3-clang-14 tar zip automake bc binfmt-support cmake dpkg-dev libelf-dev libncurses5-dev libssl-dev mesa-common-dev opencl-headers perl-base qemu qemu-user-static texinfo wget xutils-dev autopoint gperf gtk-doc-tools intltool libglib2.0-dev libltdl-dev libtool python3-libxml2 python3-mako xfonts-utils xsltproc x11-xkb-utils clang-11 sudo gcc-aarch64-linux-gnu g++-aarch64-linux-gnu rsync ssh libc6-dev lld clang build-essential vim less\
	&& useradd -ms /bin/bash imgtec && usermod -aG sudo imgtec \
	&& echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
	&& sudo mkdir /root/.ssh && sudo echo "Host *" >> /root/.ssh/config \
    	&&  sudo echo "  StrictHostKeyChecking no" >> /root/.ssh/config

WORKDIR /home/imgtec
USER imgtec
ENV HOME=/home/imgtec
ENV MIPS_ELF_ROOT=/opt/imgtec/Toolchains/mips-mti-elf/2014.07-1
ENV RISCV_ELF_ROOT=/opt/imgtec/catapult-sdk_1.0.1
ENV WINDOW_SYSTEM=nullws
ENV LINUX_ROOT="$HOME/powervr_graphics_ddk/linux"
COPY mips-mti-elf.tar.xz .
COPY Catapult_SDK_1.0.1.zip .
RUN echo "check_certificate = off" >> ~/.wgetrc \
	&& sudo mkdir -p /opt/imgtec/Toolchains \
	&& echo $LINUX_ROOT \
	&& mkdir -p "$LINUX_ROOT" \
	&& sudo mkdir -p /opt/imgtec/Toolchains \
	&& sudo tar -xJf mips-mti-elf.tar.xz && sudo tar -xf mips-mti-elf.tar -C /opt/imgtec/Toolchains/ \
	&& mkdir -p "$LINUX_ROOT" \
    && while [ "$(find . -type f -name '*.zip' | wc -l)" -gt 0 ]; do find . -type f -name "*.zip" -exec unzip -- '{}' \; -exec rm -- '{}' \;; done
	#&& sudo dpkg -i catapult-sdk_1.0.1.deb && sudo apt-get -f install
#RUN sudo apt-get update
#RUN sudo apt-get -y install libcups2
RUN sudo apt -y install ./catapult-sdk_1.0.1.deb

WORKDIR $LINUX_ROOT
ENV KERNELDIR="$LINUX_ROOT/kernel-src"
COPY --chown=imgtec:imgtec rogue_km ${LINUX_ROOT}/rogue_km
COPY --chown=imgtec:imgtec rogue ${LINUX_ROOT}/rogue
COPY --chown=imgtec:imgtec kernel-src ${LINUX_ROOT}/kernel-src
COPY --chown=imgtec:imgtec .config  $KERNELDIR/.config
ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV MULTIARCH=""
ENV LLVM_BUILD_DIR="${LINUX_ROOT}/llvm"
#ENV RGX_BVNC=36.53.104.796
RUN set -x && cd kernel-src && pwd && ls  && ./scripts/config -e drm && make oldconfig && make -j 4\
	&& mkdir "$LLVM_BUILD_DIR" && mkdir "${LINUX_ROOT}/share" && mkdir ${LINUX_ROOT}/bin

ENV PATH="${PATH}:${LINUX_ROOT}/bin"
ENV SYSROOT="${LINUX_ROOT}/sysroot-ubuntu-22.04-arm64"
COPY --chown=imgtec:imgtec aarch64-linux-gnu-sysroot-pkg-config.txt ${LINUX_ROOT}/bin/aarch64-linux-gnu-sysroot-pkg-config
COPY --chown=imgtec:imgtec aarch64-linux-gnu-sysroot-meson.txt ${LINUX_ROOT}/share/aarch64-linux-gnu-sysroot-meson
RUN sudo chmod ug+x "${LINUX_ROOT}"/bin/* 

WORKDIR $LLVM_BUILD_DIR
RUN ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$LINUX_ROOT"/rogue/build/linux/tools/prepare-llvm.sh
RUN mkdir "$SYSROOT" \
	&& wget -P "$LINUX_ROOT" http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.1-base-arm64.tar.gz \
	&&  sudo tar -xvf "${LINUX_ROOT}/ubuntu-base-22.04.1-base-arm64.tar.gz" -C "$SYSROOT" \
	&& sudo cp /etc/resolv.conf "${SYSROOT}/etc" \
	&& sudo cp /usr/bin/qemu-aarch64-static "${SYSROOT}/usr/bin" \
	&& sudo ls /proc/sys/fs/binfmt_misc \
	&& sudo cp /usr/bin/qemu-arm-static "${SYSROOT}/usr/bin" \
	&& sudo perl -i.bak -w -pe 'if (/\# (deb.*universe)/){$_="$1\n"}' "${SYSROOT}/etc/apt/sources.list"

WORKDIR /home/imgtec
COPY --chown=imgtec:imgtec chroot.sh "$SYSROOT"/
RUN sudo chroot "$SYSROOT" /chroot.sh

ENV libdrmpkg=libdrm-2.4.110
ENV libdrmdir="${LINUX_ROOT}/${libdrmpkg}"
ENV ALL_ARCH=aarch64-linux-gnu
RUN mkdir "$libdrmdir"

WORKDIR "$libdrmdir"
RUN wget -P "$LINUX_ROOT" https://dri.freedesktop.org/libdrm/${libdrmpkg}.tar.xz \
	&& tar -xvf "${LINUX_ROOT}/${libdrmpkg}.tar.xz" --strip-components=1  \
	&& for p in "${LINUX_ROOT}/rogue/lws/patches/libdrm/${libdrmpkg}/"*.patch; do patch -p1 -i "$p"; done \
	&& mkdir "${libdrmdir}/staging" \
	&& mkdir "${libdrmdir}/${ALL_ARCH}-binaries" \
	&& meson setup --cross-file="${LINUX_ROOT}/share/${ALL_ARCH}-sysroot-meson" \
    	"${libdrmdir}" "${libdrmdir}/${ALL_ARCH}-binaries" \
    	-Dc_args=--sysroot="${SYSROOT}" -Dc_link_args=--sysroot="${SYSROOT}" \
    	-Dcpp_args=--sysroot="${SYSROOT}" -Dcpp_link_args=--sysroot="${SYSROOT}" \
    	-Damdgpu=false -Dfreedreno=false -Dintel=false -Dnouveau=false \
    	-Dradeon=false -Dvc4=false -Dvmwgfx=false -Dcairo-tests=false \
    	-Dman-pages=false -Dinstall-test-programs=true

WORKDIR "${libdrmdir}/${ALL_ARCH}-binaries"
RUN DESTDIR=${libdrmdir}/staging sudo -E ninja install

WORKDIR /home/imgtec
COPY --chown=imgtec:imgtec bin bin

WORKDIR $LINUX_ROOT/rogue
RUN sed -i.bak -e '251d' build/linux/scripts/install.sh.tpl
