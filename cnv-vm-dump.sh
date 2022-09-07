#!/bin/bash
set -euo pipefail

RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'

namespace=default
action=""
_kubectl="${KUBECTL_BINARY:-oc}"
timeout=10
timestamp=$(date +%Y%m%d-%H%M%S)

options=$(getopt -o n:,h --long help,pause,dump:,list,copy:,capture_mode:,unpause -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}

capture_mode="dump"

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
    --capture_mode)
        shift;
        capture_mode=$1
        ;;
    --copy)
        action="copy"
        shift;
        filename=$1
        ;;
    --list)
        action="list"
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
    echo "Usage: script <vm> [-n <namespace>]  --pause|--dump [memory|disk]|--capture_mode [dump|snapshot]|--list|--copy [filename]|--unpause"
    exit 1
fi

vm=$1
UUID=$(${_kubectl} get vmis ${vm} -n ${namespace} --no-headers -o custom-columns=METATADA:.metadata.uid) 
POD=$(${_kubectl} get pods -n ${namespace} -l kubevirt.io/created-by=${UUID} --no-headers -o custom-columns=NAME:.metadata.name)
_exec="${_kubectl} exec  ${POD} -n ${namespace} -c compute --"
_virtctl="${VIRTCTL_BINARY:-virtctl}"
_virtctl="${_virtctl} --namespace ${namespace}"

if [ "${action}" == "pause" ]; then
    ${_virtctl} pause vm ${vm}
    ${_exec} mkdir -p /opt/kubevirt
elif [ "${action}" == "dump" ]; then
    ${_exec} mkdir -p /opt/kubevirt/external/${namespace}_${vm}/
    _virsh="${_exec} virsh -c qemu+unix:///system?socket=/run/libvirt/libvirt-sock"
    if  [ "${capture_mode}" == "dump" ]; then
        if [ "${dump_mode}" == "memory" ]; then
            ${_virsh} dump ${namespace}_${vm} /opt/kubevirt/external/${namespace}_${vm}/${namespace}_${vm}-${timestamp}.memory.dump --memory-only --verbose
            echo "Memory export is in progress..."
            ${_kubectl} cp ${namespace}/${POD}:/opt/kubevirt/external/${namespace}_${vm}/${namespace}_${vm}-${timestamp}.memory.dump ${namespace}_${vm}-${timestamp}.memory.dump
        elif [ "${dump_mode}" == "disk" ]; then
            echo "Disk export is in progress..."
            disk_paths=( $(${_exec} virsh domblklist ${namespace}_${vm} | tail -n+3 | cut -d"/" -f2-) )
            disk_count=${#disk_paths[@]}
            echo "Found ${disk_count} disks"

            for (( i=0; i<${disk_count}; i++ ));
            do
                let human_idx=i+1
                disk_path="/${disk_paths[$i]}"
                disk_name="${disk_path%/}" # strip trailing slash (if any)
                disk_name="${namespace}_${vm}-${timestamp}-${human_idx}_${disk_name##*/}"
                echo "Dumping disk #${human_idx}, named: ${disk_name}"

                ${_kubectl} cp ${namespace}/${POD}:${disk_path} ./${disk_name}

                echo "Disk ${disk_name} dumped sucessfully!"
            done

            echo "Dumped ${disk_count} disks sucessfully"
        fi
    fi
elif [ "${action}" == "list" ]; then
    ${_exec} ls -lah /opt/kubevirt/external/${namespace}_${vm}/
elif [ "${action}" == "copy" ]; then
    ${_exec} cat /opt/kubevirt/external/${namespace}_${vm}/${filename} > ${filename}
elif [ "${action}" == "unpause" ]; then
    ${_exec} bash -c "rm -rf /opt/kubevirt/*"
    ${_virtctl} unpause vm ${vm}
fi

