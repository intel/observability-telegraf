# observability-telegraf

This repo contains observability-telegraf which is a containerized version of [Telegraf agent](https://github.com/influxdata/telegraf).

Design goal is to have configured container that contains running [Telegraf agent](https://github.com/influxdata/telegraf)
with certain plugins.

## Minimum requirements
- [Linux kernel](https://en.wikipedia.org/wiki/Linux_kernel) version 3.13 or later.
- Docker version 20.10.6. [Docker installation guide](https://docs.docker.com/engine/install/).
- For specific plugin requirements see [plugin list](#input-plugins) and select plugin you are interested in.

## Pre-configuration
Pre-configuration is needed for a container to read metrics from specific plugins:

- For [Intel PowerStat plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat):
  
  Plugin is based on Linux Kernel modules that expose specific metrics over sysfs or devfs interfaces. The following 
  dependencies are expected by plugin:
  
  - intel-rapl module which exposes Intel Runtime Power Limiting metrics over sysfs (/sys/devices/virtual/powercap/intel-rapl),
  - msr kernel module that provides access to processor model specific registers over devfs (/dev/cpu/cpu%d/msr),
  - cpufreq kernel module - which exposes per-CPU Frequency over sysfs (/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq).

  Please make sure that kernel modules are loaded and running. You might have to manually enable them by using modprobe. 
  Exact commands to be executed are:

  ```
  sudo modprobe cpufreq-stats
  sudo modprobe msr
  sudo modprobe intel_rapl
  ```

- For [Redfish plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish):
  
  - The Redfish plugin needs hardware servers for which [**DMTF's Redfish**](https://redfish.dmtf.org/) is enabled.
  

- For [DPDK plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk):
  
  - The DPDK plugin needs external application built with [Data Plane Development Kit](https://www.dpdk.org/).
  - `./telegraf-intel-docker.sh` has default location of DPDK socket - `/var/run/dpdk/rte`, if DPDK socket is located 
    somewhere else, user must specify this in running stage providing --dpdk_socket_path flag.
    

## Installation

### From source
1. Install Docker 20.10.6. or newer. [Docker installation guide](https://docs.docker.com/engine/install/)
1. Clone Telegraf Intel Docker repository.
2. Go into cloned repository `cd telegraf_intel_docker`.
3. Run `./telegraf-intel-docker.sh build-run <image-name> <container-name>` from source file directory to build and run in background Docker container.

## How to use it
- See **available option** with:

    `./telegraf-intel-docker.sh`
      

- **Build and run** Telegraf Intel Docker container: 
  
    `./telegraf-intel-docker.sh build-run <image-name> <container-name>`

- **Build and run with DPDK socket path** Telegraf Intel Docker container:

  `./telegraf-intel-docker.sh build-run <image-name> <container-name> --dpdk_socket_path <socket-path>`


- **Build** Telegraf Intel Docker image:

  `./telegraf-intel-docker.sh build <image-name>`


- **Run with DPDK socket path** Telegraf Intel Docker container:

  `./telegraf-intel-docker.sh run <image-name> <container-name> --dpdk_socket_path <socket-path>`


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
- In configuration file you can load, unload or configure a plugin.

To change Telegraf configuration file:
- From source file directory edit Telegraf configuration file using text editor 
  (e.g. nano): 
  
  `nano telegraf/telegraf.conf`


- Use script to reload Telegraf configuration file and load new plugins (_my-telegraf_ is a container name): 
  
  `./telegraf-intel-docker.sh restart my-image my-container`
  

- To check if everything is correct you can check Telegraf logs: 
  
  `./telegraf-intel-docker.sh logs my-container`

### Usage example

- Creating and running Telegraf Docker image: 
  
  `./telegraf-intel-docker.sh build-run my-image my-container`
  
  This command will create and run Telegraf docker image with given name, in this case it is "telegraf-docker".
  

- To see logs from Telegraf in the container: 
  
  `./telegraf-intel-docker.sh logs my-container`
  
  To exit viewing logs press: `CTRL + C`.


- To load new Telegraf configuration file: 
  
  `./telegraf-intel-docker.sh restart my-image my-container`
  
  This will restart the container, and run it with the new configuration.


- To build and run the container with DPDK socket path:

  `./telegraf-intel-docker.sh build-run my-image my-container --dpdk_socket_path /var/run/dpdk/rte`




## Default configured plugins:
### Input plugins
1. [Intel PowerStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_powerstat)
2. [Intel RDT](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/intel_rdt)
3. [CGroup](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/cgroup)
4. [CPU](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/cpu)
5. [Disk](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/disk)
6. [Disk IO](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/diskio)
7. [DNS Query](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dns_query)
8. [DPDK](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/dpdk)
9. [ETH Tool](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ethtool)
10. [IP Tables](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/iptables)
11. [IPMI Sensor](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ipmi_sensor)
12. [Kernel VMStat](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/kernel_vmstat)
13. [Mem](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/mem)
14. [Net](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/net)
15. [Ping](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ping)
16. [RAS](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/ras)
17. [Redfish](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/redfish)
18. [Smart](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/smart)
19. [System](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/system)
20. [Temp](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/temp) 
### Output plugins
1. [File](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/file)
2. [Prometheus client](https://github.com/influxdata/telegraf/tree/master/plugins/outputs/prometheus_client)