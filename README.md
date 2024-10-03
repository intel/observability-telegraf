# observability-telegraf

This repo contains observability-telegraf which is a containerized version of
[Telegraf agent](https://github.com/influxdata/telegraf).

Design goal is to have configured container that contains running [Telegraf agent](https://github.com/influxdata/telegraf)
with certain plugins.

## Minimum requirements

- [Linux kernel](https://en.wikipedia.org/wiki/Linux_kernel) version 3.13 or later.
- Docker version 20.10.6.
[Docker installation guide](https://docs.docker.com/engine/install/).
- Plugin specific requirements are available in the [plugin list](#input-plugins).

## Pre-configuration

Pre-configuration is needed for a container to read metrics from specific plugins:

### [Iptables Input Plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/iptables)

By default, plugin uses command `sudo iptables -nvL INPUT -x`. `iptables` has become a legacy tool and has been
replaced by `iptables-nft`. If there is a need to use `iptables-nft` line `#binary = "iptables-ntf"` should be
uncommented in the configuration.

### [Intel PowerStat plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat)

Plugin is based on Linux Kernel modules that expose specific metrics over
`sysfs` or `devfs` interfaces. The following dependencies are expected by
plugin:

- _intel-rapl_ module which exposes Intel Runtime Power Limiting metrics over
  `sysfs` (`/sys/devices/virtual/powercap/intel-rapl`),
- _msr_ kernel module that provides access to processor model specific
  registers over `devfs` (`/dev/cpu/cpu%d/msr`),
- _cpufreq_ kernel module - which exposes per-CPU Frequency over `sysfs`
  (`/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq`).
- _intel-uncore-frequency_ module exposes Intel uncore frequency metrics
  over `sysfs` (`/sys/devices/system/cpu/intel_uncore_frequency`),

Minimum kernel version required is 3.13 to satisfy most of the requirements,
for `uncore_frequency` metrics `intel-uncore-frequency` module is required
(available since kernel 5.6).

Please make sure that kernel modules are loaded and running (cpufreq is
integrated in kernel). Modules might have to be manually enabled by using
`modprobe`. Depending on the kernel version, run commands:

```sh
# kernel 5.x.x:
sudo modprobe rapl
sudo modprobe msr
sudo modprobe intel_rapl_common
sudo modprobe intel_rapl_msr

# also for kernel >= 5.6.0
sudo modprobe intel-uncore-frequency

# kernel 4.x.x:
sudo modprobe msr
sudo modprobe intel_rapl
```
  
### [Redfish plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish)

The Redfish plugin needs hardware servers for which
[**DMTF's Redfish**](https://redfish.dmtf.org/) is enabled.

For quick check proper work of redfish plugin, you can do a mockup:
Mockup must be preformed on HOST!

1. Get a source code: `git clone https://opendev.org/x/python-redfish.git`
2. Go into dmtf/mockup_0.99.0a folder.
3. Run `./buildImage.sh` and `./run-redfish-simulator.sh`
4. Check that a container is running and listening on port 8000, by command: docker ps
5. Now run observability-telegraf with redfish plugin.
  
### [DPDK plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk)

- The DPDK plugin needs external application built with
[Data Plane Development Kit](https://www.dpdk.org/).
- `./telegraf-intel-docker.sh` has default location of DPDK socket -`/var/run/dpdk/rte`, if DPDK socket is located
somewhere else, user must specify this in running stage providing `--dpdk_socket_path` flag. Providing path to a
directory that contains the hosts' own Docker socket file is not recommended.

Make sure the container has read and write access to the socket.
It can be done e.g. by `chmod a+rw /var/run/dpdk/rte/dpdk_telemetry.v2"`

### [Intel PMU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_pmu)

The plugin requires JSON files with event definitions to work properly. Those can be specified in `./telegraf-intel-docker.sh`
by providing `--pmu_events` parameter. Providing path to a directory that contains the hosts' own Docker socket file
is not recommended.

More information about event definitions and where to get them should be found in plugin's
[README](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/intel_pmu/README.md).

### [Libvirt](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/libvirt)

The script `telegraf-intel-docker.sh` has a default location for the libvirt socket at `/var/run/libvirt/libvirt-sock`. If the libvirt socket is located elsewhere, users must provide the `--libvirt_socket_path` flag at runtime to specify the custom location. It is not recommended to use a directory that contains the host's own libvirt socket file.

Make sure the container has write access to the socket.
It can be done e.g. by `chmod a+w /var/run/libvirt/libvirt-sock"`

Similarly, the script assumes that the default location of libvirt TLS certificates is at `/etc/pki/CA`. However, users can override this location by providing the `--libvirt_tls_cert` parameter at runtime with the desired directory path.

Additionally, the script assumes that the `.ssh` directory is located in the user's home directory at `$HOME/.ssh`. If this is not the case, users can specify an alternate location at runtime by using the `--ssh_dir` parameter.

More information about event definitions and where to get them should be found in plugin's
[README](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/libvirt).

### [P4Runtime](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/p4runtime)

The script `telegraf-intel-docker.sh` assumes that the default location of P4Runtime TLS certificates is at `/etc/pki/CA`. However, users can override this location by providing the `--p4runtime_tls_cert` parameter at runtime with the desired directory path.

### [RAS](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ras)

If rasdaemon exists on the host OS, please make sure rasdaemon version on host matches exactly v0.6.7 (as the container does).
Then mount the rasdaemon library directory to the container, so that both versions are kept in sync:
`./telegraf-intel-docker.sh --use-host-rasdaemon`. An alternative is to remove rasdaemon from the host OS.

### [Intel DLB](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_dlb)

- The Intel DLB plugin needs external application built with
[Data Plane Development Kit](https://www.dpdk.org/) and installed
[Intel® Dynamic Load Balancer Driver](https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html).

- `./telegraf-intel-docker.sh` has default location of DPDK socket -`/var/run/dpdk/rte`, if DPDK socket is located
somewhere else, user must specify this in running stage providing `--dpdk_socket_path` flag. Providing path to a
directory that contains the hosts' own Docker socket file is not recommended.

Make sure the container has read and write access to the socket.
It can be done e.g. by `chmod a+rw /var/run/dpdk/rte/dpdk_telemetry.v2"`

### [Intel Baseband](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_baseband)

Intel Baseband Accelerator Input Plugin requires a properly configured and running [pf-bb-config](https://github.com/intel/pf-bb-config).
When running in daemon mode (VFIO mode) the pf_bb_config application is running as a service and exposes a socket
for CLI interaction. The path to the socket user must specify in the option `--intel_baseband_socket_path`
(eg `--intel_baseband_socket_path /tmp/pf_bb_config.0000:b1:00.0.sock`).
The response from socket is stored from the `.log` file (eg `/var/log/pf_bb_cfg_0000:b1:00.0.log`).
If pf-bb-config creates files ending in `.log` and `_resposne.log`, select the file `_resposne.log`.
The path to the file user must specify in the `--intel_baseband_log_path` option (for the example above it will be
`--intel_baseband_log_path /var/log/pf_bb_cfg_0000:b1:00.0.log` or, if there is a file `_resposne.log`,
`intel_baseband_log_path /var/log/pf_bb_cfg_0000:b1:00.0_response.log`).

For correct operation of operator telegraph user must specify both options (`--intel_baseband_socket_path` and `--intel_baseband_log_path`).
Remember to set the same values in the telegraf.conf file.

## Installation

### From source

1. Install Docker 20.10.6. or newer. [Docker installation guide](https://docs.docker.com/engine/install/)
2. Clone Telegraf Intel Docker repository. Cloning this repo into /tmp or any privileged directory is not recommended.
3. Go into cloned repository `cd telegraf_intel_docker`.
4. Run `./telegraf-intel-docker.sh build-run <image-name> <container-name>` from source file directory to build and run
Docker container in background. Provide valid image and container names in place of `<image-name>` and
   `<container-name>`.

## How to use it

- See **available options** with:

    `./telegraf-intel-docker.sh`

- **Build and run** Telegraf Intel Docker container:

    `./telegraf-intel-docker.sh build-run <image-name> <container-name>`

- **Build and run with DPDK socket path**:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --dpdk_socket_path <socket-path>`

- **Build and run with mounted rasdaemon folder**:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --use-host-rasdaemon`

- **Build and run with path to directory with PMU events definitions**:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --pmu_events <events definition path>`

- **Build** Telegraf Intel Docker image:

  `./telegraf-intel-docker.sh build <image-name>`

- **Run with DPDK socket path**:

  `./telegraf-intel-docker.sh run <image-name> <container-name> --dpdk_socket_path <socket-path>`

- **Run with non-default libvirt socket path, customized location of .ssh directory and tls certs**:

  `./telegraf-intel-docker.sh run <image-name> <container-name> --libvirt_socket_path <socket_path> --ssh_dir <ssh_dir> --libvirt_tls_cert <certs_dir>`

- **Run with mounted rasdaemon folder**:

  `./telegraf-intel-docker.sh run <image-name> <container-name> --use-host-rasdaemon`

- **Run with path to directory with PMU events definitions**:

  `./telegraf-intel-docker.sh run <image-name> <container-name> --pmu_events <events definition path>`

- **Restart** Telegraf Intel Docker container (e.g. for reload [Telegraf](https://github.com/influxdata/telegraf)
configuration file):

    `./telegraf-intel-docker.sh restart <image-name> <container-name>`

- **Stop and remove all** Telegraf Intel Docker container, and images linked to it:

    `./telegraf-intel-docker.sh remove <image-name> <container-name>`

- **Remove** Telegraf Intel Docker images:

  `./telegraf-intel-docker.sh remove-build <image-name>`

- **Enter** Telegraf Intel Docker container via the bash:

    `./telegraf-intel-docker.sh enter <container-name>`

- See [Telegraf](https://github.com/influxdata/telegraf) **logs** with:

    `./telegraf-intel-docker.sh logs <container-name>`

### Changing [Telegraf](https://github.com/influxdata/telegraf) configuration file

What is Telegraf configuration file?

- Telegraf's configuration file is written using [TOML](https://github.com/toml-lang/toml#toml) and is composed of three
  sections: [global tags](https://github.com/influxdata/telegraf/tree/master/config#global-tags),
  [agent settings](https://github.com/influxdata/telegraf/tree/master/config#agent),
  and [plugins](https://github.com/influxdata/telegraf/tree/master/config#plugins).
- Plugins can be loaded, unloaded or configured in configuration file.

To change Telegraf configuration file:

- From source file directory edit Telegraf configuration file using text editor (e.g. nano):
  
  `nano telegraf/telegraf.conf`

- Use script to reload Telegraf configuration file and load new plugins:
  
  `./telegraf-intel-docker.sh restart <image-name> <container-name>`

- Verify Telegraf logs to check that everything works as expected:
  
  `./telegraf-intel-docker.sh logs <container-name>`

### Usage example

- Creating and running Telegraf Docker image:
  
  `./telegraf-intel-docker.sh build-run <image-name> <container-name>`
  
  This command will create and run Telegraf docker image with given name.

- To see logs from Telegraf in the container:
  
  `./telegraf-intel-docker.sh logs <container-name>`
  
  To exit viewing logs press: `CTRL + C`.

- To load new Telegraf configuration file:
  
  `./telegraf-intel-docker.sh restart <image-name> <container-name>` - This will restart the container, and run it with the new
configuration.

- To build and run the container with DPDK socket path:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --dpdk_socket_path /var/run/dpdk/rte`

- To build and run the container with necessary files for Intel Baseband Accelerator Input Plugin:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --intel_baseband_socket_path /tmp/pf_bb_config.0000:b1:00.0.sock --intel_baseband_log_path /var/log/pf_bb_cfg_0000:b1:00.0.log`

---

## Available plugins

### Input plugins

List of supported Telegraf input plugins.

#### Enabled by default

The following plugins should work on a majority of the host's configurations.

1. [CGroup](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/cgroup)
2. [CPU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/cpu)
3. [Disk](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/disk)
4. [Disk IO](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/diskio)
5. [DNS Query](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dns_query)
6. [ETH Tool](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ethtool)
7. [Hugepages](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/hugepages)
8. [IP Tables](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/iptables)
9. [Kernel VMStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/kernel_vmstat)
10. [Mem](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/mem)
11. [Net](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/net)
12. [Ping](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ping)
13. [Smart](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/smart)
14. [System](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/system)
15. [Temp](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/temp)

#### Disabled by default

Some plugins need special attention regarding host's configuration. Observability Telegraf supports them, so they
can be enabled by uncommenting associated config fields in `telegraf/telegraf.conf` file. Please ensure configuration requirements are properly fulfilled
for plugins listed below.

1. [Intel Baseband](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_baseband)
2. [Intel DLB](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_dlb)
3. [Intel PowerStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat)
4. [Intel RDT](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_rdt)
5. [Intel PMU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_pmu)
6. [DPDK](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk)
7. [IPMI Sensor](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ipmi_sensor)
8. [Libvirt](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/libvirt)
9. [P4Runtime](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/p4runtime)
10. [RAS](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ras)
11. [Redfish](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish)

### Output plugins

List of supported Telegraf output plugins enabled by default.

1. [File](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/file)
2. [Prometheus client](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/prometheus_client)

### Changelog

#### 1.3.0

- Update telegraf version: 1.24.3 -> 1.27.4
- Add P4Runtime plugin (disabled by default)
- Add Intel DLB plugin (disabled by default)
- Add Intel Baseband plugin (disabled by default)
- Add new features: cpu_base_frequency for Powerstat plugin
- Update the final alpine image: 3.16 -> 3.18

#### 1.2.0

- Update telegraf version: 1.21.3 -> 1.24.3
- Update version of pqos (intel_cmt_cat): 4.2.0 -> 4.4.1
- Add Hugepages plugin (enabled by default)
- Add new features: uncore_freq and max_turbo_freq for Powerstat plugin
- Update the final alpine image: 3.15 -> 3.16
