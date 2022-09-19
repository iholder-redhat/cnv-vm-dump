#!/bin/bash
set -euo pipefail

RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'

DISK_TYPE_FILE="image file"
DISK_TYPE_BLOCK_DEVICE="block device"

namespace=default
action=""
_kubectl="${KUBECTL_BINARY:-oc}"
timeout=10
timestamp=$(date +%Y%m%d-%H%M%S)

options=$(getopt -o n:,h --long help,pause,dump:,unpause -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}

eval set -- "$options"
while true; do
    case "$1" in
    --pause)
        action="pause"
        ;;
    --dump)
        action="dump"
        shift;
        dump_mode=$1
        ;;
    --unpause)
        action="unpause"
        ;;
    --help)
        action="help"
        ;;
    -h)
        action="help"
        ;;
    -n)
        shift; # The arg is next in position args
        namespace=$1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
shift $(expr $OPTIND - 1 )

if [ "${action}" == "help" ]; then
    echo "Usage: script <vm> [-n <namespace>]  --pause|--dump [memory|disk]|--unpause"
    echo "Environment variables: VIRTCTL_BINARY, KUBECTL_BINARY."
    exit 1
fi

vm=$1
UUID=$(${_kubectl} get vmis ${vm} -n ${namespace} --no-headers -o custom-columns=METATADA:.metadata.uid) 
POD=$(${_kubectl} get pods -n ${namespace} -l kubevirt.io/created-by=${UUID} --no-headers -o custom-columns=NAME:.metadata.name)
_exec="${_kubectl} exec  ${POD} -n ${namespace} -c compute --"
_virtctl="${VIRTCTL_BINARY:-virtctl}"
_virtctl="${_virtctl} --namespace ${namespace}"
TMP_DIR="/opt/kubevirt/external/${namespace}_${vm}/"

log () {
    msg=$1
    echo "===== [Info]: $1"
}

expect_vm_paused () {
  vm_status=`${_kubectl} get vm ${vm} -n ${namespace} -o=custom-columns='STATUS:status.printableStatus' | tail -n1`
  if [ "${vm_status}" != "Paused" ]; then
    log "VM must be paused to perform this operation. VM ${vm} is in status ${vm_status}"
    exit
  fi
}

if [ "${action}" == "pause" ]; then
    ${_virtctl} pause vm ${vm}
    ${_exec} mkdir -p /opt/kubevirt
elif [ "${action}" == "dump" ]; then
    ${_exec} mkdir -p ${TMP_DIR}
    _virsh="${_exec} virsh -c qemu+unix:///system?socket=/run/libvirt/libvirt-sock"
    expect_vm_paused
    if [ "${dump_mode}" == "memory" ]; then
        dump_name="${namespace}_${vm}-${timestamp}.memory.dump"
        ${_virsh} dump ${namespace}_${vm} ${TMP_DIR}/${dump_name} --memory-only --verbose
        log "Memory export is in progress..."
        ${_exec} cat ${TMP_DIR}/${dump_name} > ${dump_name}
        ${_exec} rm -f ${TMP_DIR}/${dump_name}
        log "Sucessfully dumped memory to ${dump_name}"
    elif [ "${dump_mode}" == "disk" ]; then
        log "Disk export is in progress..."
        disk_paths=( $(${_exec} virsh domblklist ${namespace}_${vm} | tail -n+3 | cut -d"/" -f2-) )
        disk_count=${#disk_paths[@]}
        log "Found ${disk_count} disks"

        for (( i=0; i<${disk_count}; i++ ));
        do
            let human_idx=i+1
            disk_path="/${disk_paths[$i]}"
            disk_name="${disk_path%/}" # strip trailing slash (if any)
            disk_name="${namespace}_${vm}-${timestamp}-${human_idx}_${disk_name##*/}"
            disk_type=`${_exec} bash -c "if [ -b ${disk_path} ]; then echo ${DISK_TYPE_BLOCK_DEVICE}; else echo ${DISK_TYPE_FILE}; fi"`
            log "Dumping disk #${human_idx}, named: ${disk_name}. type: ${disk_type}"
            log "DISK PATH: ${disk_path}"

            # Dump block device to a file
            if [ "${disk_type}" == "${DISK_TYPE_BLOCK_DEVICE}" ]; then
                log "Starting to dump block device into a file image"
                disk_name="${disk_name}.img"
                dd_cmd="dd if=${disk_path} bs=32k status=progress"
                ${_exec} bash -c "${dd_cmd}" > ${disk_name}
            fi

            if [ "${disk_type}" == "${DISK_TYPE_FILE}" ]; then
                log "Starting to copy the disk image file"
                ${_kubectl} cp ${namespace}/${POD}:${disk_path} ./${disk_name} --retries=-1 -c "compute"
            fi

            log "Disk ${disk_name} dumped sucessfully!"
        done

        log "Dumped ${disk_count} disks sucessfully"
    fi
elif [ "${action}" == "unpause" ]; then
    ${_exec} bash -c "rm -rf /opt/kubevirt/*"
    ${_virtctl} unpause vm ${vm}
fi

