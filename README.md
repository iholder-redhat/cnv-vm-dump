# cnv-vm-dump
Utility to perform "virsh dump" for Openshift CNV guest workloads. It creates a dump file containing the core of the guest virtual machine so that it can be analyzed, for example by the crash utility.
```
[root@ocp-stg-bastion cnv-vm-dump]# ./cnv-vm-dump.sh --help
Usage: script <vm> [-n <namespace>]  --pause|--dump [full|memory]|--list|--copy [filename]|--unpause
```

## HowTo

### Step 1 - Pause the target VM within the defined namespace
```
[root@bastion cnv-vm-dump]# oc get vmi -n smarunich-cnv
NAME                    AGE   PHASE     IP             NODENAME
smarunich-cnv-win10-0   46m   Running   10.128.0.1   worker-0.redhat.com
[root@ocp-stg-bastion cnv-vm-dump]# ./cnv-vm-dump.sh -n smarunich-cnv smarunich-cnv-win10-0 --pause
VMI smarunich-cnv-win10-1 was scheduled to pause
```
### Step 2 - Perform the target VM dump
There are two options available:
* full - to perform complete VM dump (to include memory)
* memory - to perform memory VM dump only
```
[root@ocp-stg-bastion cnv-vm-dump]#  ./cnv-vm-dump.sh -n smarunich-cnv smarunich-cnv-win10-0 --dump memory
Dump: [100 %]
Domain smarunich-cnv_smarunich-cnv-win10-0 dumped to /var/run/kubevirt/dumps/smarunich-cnv_smarunich-cnv-win10-0/smarunich-cnv_smarunich-cnv-win10-0-20210331-145428.memory.dump
```
### Step 3 - List available VM dumps for copy
```
[root@ocp-stg-bastion cnv-vm-dump]#  ./cnv-vm-dump.sh -n smarunich-cnv smarunich-cnv-win10-0 --list
smarunich-cnv_smarunich-cnv-win10-0-20210331-145428.memory.dump
```
### Step 4 - Copy the target VM dump
```
[root@ocp-stg-bastion cnv-vm-dump]#  ./cnv-vm-dump.sh -n smarunich-cnv smarunich-cnv-win10-0 --copy smarunich-cnv_smarunich-cnv-win10-0-20210331-145428.memory.dump
Defaulting container name to compute.
tar: Removing leading `/' from member names
[root@ocp-stg-bastion cnv-vm-dump]#  ls
smarunich-cnv_smarunich-cnv-win10-0-20210331-145428.memory.dump
```
### Step 5 - Unpause the target VM
```

```