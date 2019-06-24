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


## Networking

- eth0 makes use of macOS' vmnet, where macOS provides the DHCP, bridge and NAT configuration. This interface will be bridged to the host's bridge100. Vmnet requires the use of the IP address as assigned by DHCP. All other traffic will be firewalled, so static IPs are not supported for this interface.
- eth1 makes use of a TAP interface, and is added to the configured bridge interface (eg. bridge1). No DHCP is configured, so static IP addressing is required.

### Create macOS Bridge interface for TAP interfaces

1. Open "Systems Preferences"
2. Open the "Network" preference pane
3. Click the "cog" drop down menu and select "Manage Virtual Interfaces..."
4. Click the "+" button and select "New Bridge..."
5. Enter a name for the new bridge like "bridge1" and do not select any interfaces to include.
6. Click "Create"
7. Take note of the BSD Name of the bridge created. This is the interface name used like `ifconfig bridge1`. If this is not bridge1, edit this project's `config` file appropriately.
8. Click "Done"
9. Select the new bridge interface in the Network preference pane.
10. Select from the Configure IPv4 pull down to "Manually", and set the "IP Address" to "192.168.99.1". Set the "Subnet Mask" to "255.255.255.0".
11. Click "Apply"
12. Close "System Preferences"

- Note, when the bridge device has no tap interfaces attached to it, macOS shows it as "Not Connected" and does not apply the configured IP address.
- Note, if you were to use the terminal to create and IP address the bridge interface (eg. `ifconfig bridge1 create`), it will be lost as the first VM comes up with a vmnet interface. If appears macOS largely resets the network configuration to what is in the Network Preferences on each invocation of vmnet. In fact, additional care in this project is taken to record existing bridge members before VM execution is done, as while the bridge itself isn't removed due to the above config, the member tap interfaces do get removed. This project re-adds any members it finds before VM start. Thus, there will be some quick network hangs on the eth1 interface of running VMs, during a neighbor VM startup.

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
$ ssh -i .run/.ssh/hyperkit rancher@192.168.99.10
[rancher@ros-vm0 ~]$
```
