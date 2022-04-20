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

### [Intel PowerStat plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat)

Plugin is based on Linux Kernel modules that expose specific metrics over `sysfs` or `devfs` interfaces.
The following dependencies are expected by plugin:

- _intel-rapl_ module which exposes Intel Runtime Power Limiting metrics over `sysfs` (`/sys/devices/virtual/powercap/intel-rapl`),
- _msr_ kernel module that provides access to processor model specific registers over `devfs` (`/dev/cpu/cpu%d/msr`),
- _cpufreq_ kernel module - which exposes per-CPU Frequency over `sysfs` (`/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq`).

Minimum kernel version required is 3.13 to satisfy all requirements.

Please make sure that kernel modules are loaded and running (cpufreq is integrated in kernel). Modules might have to be manually enabled by using `modprobe`.
Depending on the kernel version, run commands:

```sh
# kernel 5.x.x:
sudo modprobe rapl
subo modprobe msr
sudo modprobe intel_rapl_common
sudo modprobe intel_rapl_msr

# kernel 4.x.x:
sudo modprobe msr
sudo modprobe intel_rapl
```
  
### [Redfish plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish)

The Redfish plugin needs hardware servers for which
[**DMTF's Redfish**](https://redfish.dmtf.org/) is enabled.
  
### [DPDK plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk)

- The DPDK plugin needs external application built with
[Data Plane Development Kit](https://www.dpdk.org/).
- `./telegraf-intel-docker.sh` has default location of DPDK socket -`/var/run/dpdk/rte`, if DPDK socket is located
somewhere else, user must specify this in running stage providing `--dpdk_socket_path` flag.

### [Intel PMU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_pmu)

The plugin requires JSON files with event definitions to work properly. Those can be specified in `./telegraf-intel-docker.sh`
by providing `--pmu_events` parameter. More information about event definitions and where to get them should be found in plugin's
[README](https://github.com/influxdata/telegraf/blob/master/plugins/inputs/intel_pmu/README.md).

### [RAS](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ras)

If rasdaemon exists on the host OS, please make sure rasdaemon version on host matches exactly v0.6.7 (as the container does).
Then mount the rasdaemon library directory to the container, so that both versions are kept in sync:
`./telegraf-intel-docker.sh --use-host-rasdaemon`. An alternative is to remove rasdaemon from the host OS.

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
7. [IP Tables](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/iptables)
8. [Kernel VMStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/kernel_vmstat)
9. [Mem](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/mem)
10. [Net](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/net)
11. [Ping](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ping)
12. [Smart](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/smart)
13. [System](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/system)
14. [Temp](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/temp)

#### Disabled by default

Some plugins need special attention regarding host's configuration. Observability Telegraf supports them, so they
can be enabled by uncommenting associated config fields in `telegraf/telegraf.conf` file. Please ensure configuration requirements are properly fulfilled
for plugins listed below.

1. [Intel PowerStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat)
2. [Intel RDT](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_rdt)
3. [Intel PMU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_pmu)
4. [DPDK](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk)
5. [IPMI Sensor](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ipmi_sensor)
6. [RAS](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ras)
7. [Redfish](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish)

### Output plugins

List of supported Telegraf output plugins enabled by default.

1. [File](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/file)
2. [Prometheus client](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/prometheus_client)
