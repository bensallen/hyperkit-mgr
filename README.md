# hyperkit-mgr

A minimal shell based virtual machine management environment built around hyperkit.

## Dependencies

- hyperkit - https://github.com/moby/hyperkit
- MacOS TunTap - http://tuntaposx.sourceforge.net
- qemu-img from qemu - https://www.qemu.org
- GNU Coreutils - https://www.gnu.org/software/coreutils/

```shell
brew install coreutils hyperkit qemu
brew cask install tuntap
```

- Note, the RancherOS config is using behavior in https://github.com/rancher/os/pull/2805 to pass ssh_authorized_keys via the kernel cmdline.
- Sudo is used where privileged execution is needed: network configuration, and execution of hyperkit itself to make use of vmnet.

## Manage VMs

### Start VMs

```shell
$ ./start.sh
RancherOS Version: v1.5.2
* Booting VM 0 ...
* Booting VM 1 ...
* Booting VM 2 ...
* Attaching tap interface(s) to bridge1 ...
* Console TTYs (escape via Ctrl-a k):
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/0/tty
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/1/tty
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/2/tty
* Checking for SSH access ...
  - ros-vm0 SSH timed out, retrying ...
  - ros-vm0 SSH timed out, retrying ...
  - ros-vm0 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.10
  - ros-vm1 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.11
  - ros-vm2 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.12
```

start.sh will skip running VMs:

```shell
$ ./start.sh
RancherOS Version: v1.5.2
* Skipping vm2, existing process: 28024
* Booting VM 0 ...
* Booting VM 1 ...
* Attaching tap interface(s) to bridge1 ...
* Console TTYs (escape via Ctrl-a k):
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/0/tty
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/1/tty
* Checking for SSH access ...
  - ros-vm0 SSH timed out, retrying ...
  - ros-vm0 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.10
  - ros-vm1 SSH timed out, retrying ...
  - ros-vm1 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.11
```

### Gracefully Stop VMs

```shell
$ ./stop.sh
$ ./status.sh
* VM 0 is running, PID: 28312
* VM 1 is running, PID: 28338
* VM 2 is running, PID: 28024
$ ./status.sh
* VM 0 missing pid file, gracefully shutdown / never started
* VM 1 missing pid file, gracefully shutdown / never started
* VM 2 missing pid file, gracefully shutdown / never started
```

### Start VM0

```shell
$ ./start.sh 0
RancherOS Version: v1.5.2
* Booting VM 0 ...
* Attaching tap interface(s) to bridge1 ...
* Console TTYs (escape via Ctrl-a k):
  - screen /Users/ballen/Desktop/hyperkit-mgr/.run/vms/0/tty
* Checking for SSH access ...
  - ros-vm0 SSH timed out, retrying ...
  - ros-vm0 SSH available via: ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.10
```

### Stop VM0

```shell
$ ./stop.sh 0
$ ./status.sh 0
* VM 0 missing pid file, gracefully shutdown / never started
```

### Status of VMs

```shell
$ ./status.sh
* VM 0 missing pid file, gracefully shutdown / never started
* VM 1 is stopped, ungraceful shutdown, PID: 28002
* VM 2 is running, PID: 28024
```

### Connect to Console

```shell
$ screen .run/vms/0/tty
```

- Use Ctrl-a k to exit the screen session

### SSH to the RancherOS VM

```shell
$ ssh -i /Users/ballen/Desktop/hyperkit-mgr/.run/.ssh/hyperkit rancher@192.168.99.10
[rancher@ros-vm0 ~]$
```
