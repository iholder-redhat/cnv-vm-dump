# vm-dump
Utility to dump VM's memory / disk for Kubevirt / Openshift CNV guest workloads.
The dumped files can later be analized by tools such as [volatility](https://github.com/volatilityfoundation/volatility3)
and [crash](https://github.com/crash-utility/crash).
```
[root@iholder cnv-vm-dump]# ./cnv-vm-dump.sh --help
Usage: script <vm> [-n <namespace>]  --pause|--dump [memory|disk]|--unpause
Environment variables: VIRTCTL_BINARY, KUBECTL_BINARY.
```

## Requirements

- oc
    - or kubectl with Kubevirt installed. Edit `KUBECTL_BINARY` variable to point it into any kubectl-like tool
    - Example: `export KUBECTL_BINARY='kubevirt/cluster-up/kubectl.sh'` 
- virtctl
    - Edit `VIRTCTL_BINARY` variable to point it into any virtctl-like tool
    - Example: `export VIRTCTL_BINARY='kubevirt/cluster-up/virtctl.sh'`

## Tutorial

For plain Kubevirt users, replace `oc` with `kubectl`.

### Step 1 - Pause the target VM within the defined namespace
```
[root@iholder cnv-vm-dump]# oc get vmi -n forensics-cnv
NAME                    AGE   PHASE     IP             NODENAME
forensics-cnv-win10-0   16m   Running   10.128.2.207   worker-0.redhat.com
[root@iholder cnv-vm-dump]# ./cnv-vm-dump.sh -n forensics-cnv forensics-cnv-win10-0  --pause
VMI forensics-cnv-win10-0 was scheduled to pause
```

### Step 2 - Dump VM memory and / or disk
### Dump VM memory
To perform memory dump:
```bash
[root@iholder cnv-vm-dump]#  ./cnv-vm-dump.sh vm-fedora --dump memory
Dump: [100 %]
Domain 'default_vm-fedora' dumped to /opt/kubevirt/external/default_vm-fedora/default_vm-fedora-20220907-114251.memory.dump

Memory export is in progress...
Sucessfully dumped memory to default_vm-fedora-20220907-114251.memory.dump
```

### Dump VM memory
To perform disk dump:
```bash
[root@iholder cnv-vm-dump]#  ./cnv-vm-dump.sh vm-fedora --dump disk
Disk export is in progress...
Found 2 disks
Dumping disk #1, named: default_vm-fedora-20220907-113918-1_disk.qcow2
Disk default_vm-fedora-20220907-113918-1_disk.qcow2 dumped sucessfully!
Dumping disk #2, named: default_vm-fedora-20220907-113918-2_noCloud.iso
Disk default_vm-fedora-20220907-113918-2_noCloud.iso dumped sucessfully!
Dumped 2 disks sucessfully

```

### Step 3 - Unpause the target VM
```
[root@iholder cnv-vm-dump]#  ./cnv-vm-dump.sh -n forensics-cnv forensics-cnv-win10-0 --unpause
VMI forensics-cnv-win10-0 was scheduled to unpause
```
