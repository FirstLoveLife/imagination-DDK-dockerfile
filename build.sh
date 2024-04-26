#/bin/env bash

#RGX_BVNC=36.53.104.796 # for bxs
: ${RGX_BVNC:=36.52.104.182}

: ${CONTAINER:=imgtec_container}
: ${IP:=bxm}
: ${VENDOR:=ambarella}
: ${WINDOW_SYSTEM:=nullws}
: ${KERNEL_VERSION:=5.15.136}
: ${LIBDRM_VERSION:=2.4.110}
NAME=${VENDOR}_${IP}

DISCIMAGE=/home/imgtec/${IP}-DISCIMAGE
BUILD_TYPE=debug
libdrmpkg=libdrm-${LIBDRM_VERSION}
libdrmdir=/home/imgtec/powervr_graphics_ddk/linux/${libdrmpkg}

#um
sudo docker exec $CONTAINER bash -c "RGX_BVNC=${RGX_BVNC} PVR_BUILD_DIR=$NAME BUILD=${BUILD_TYPE} PVRSRV_NEED_PVR_DPF=1 PVRSRV_NEED_PVR_ASSERT=1 WINDOW_SYSTEM=${WINDOW_SYSTEM} PDUMP=1 make -j 10"
# 23.1/23.2 needs this fix.
sudo docker exec $CONTAINER bash -c "sed -i '251{/^$/s//fi/}' ./binary_${NAME}_${WINDOW_SYSTEM}_${BUILD_TYPE}/install.sh"
sudo docker exec $CONTAINER bash -c "mkdir ${DISCIMAGE}"
sudo docker exec $CONTAINER bash -c "DISCIMAGE=${DISCIMAGE} sudo -E ./binary_${NAME}_${WINDOW_SYSTEM}_${BUILD_TYPE}/install.sh"
sudo docker exec $CONTAINER bash -c "sudo cp -dPrf ${libdrmdir}/staging/* ${DISCIMAGE}/"

#km
sudo docker exec $CONTAINER bash -c "sudo mkdir -p ${DISCIMAGE}/lib/modules/${KERNEL_VERSION}/extra/"
sudo docker exec $CONTAINER bash -c "cd ../rogue_km && RGX_BVNC=${RGX_BVNC} PVR_BUILD_DIR=$NAME BUILD=${BUILD_TYPE} PVRSRV_NEED_PVR_DPF=1 PVRSRV_NEED_PVR_ASSERT=1 WINDOW_SYSTEM=${WINDOW_SYSTEM} PDUMP=1 make -j 10 && sudo cp binary_${NAME}_${WINDOW_SYSTEM}_${BUILD_TYPE}/target_aarch64/*.ko $DISCIMAGE/lib/modules/${KERNEL_VERSION}/extra/"

sudo docker cp $CONTAINER:$DISCIMAGE ./
