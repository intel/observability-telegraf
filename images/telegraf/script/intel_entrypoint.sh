#!/bin/sh

#Script below is an extension of the script from influxdata-docker.
#Extension consists adding more capabilities for telegraf application.
#Link to original script:
#https://github.com/influxdata/influxdata-docker/blob/master/telegraf/1.27/alpine/entrypoint.sh

set -e

if [ "${1:0:1}" = '-' ]; then
    set -- telegraf "$@"
fi

if [ "$(id -u)" -ne 0 ]; then
    exec "$@"
else
    # Allow telegraf to send ICMP packets and bind to privileged ports (cap_net_raw,cap_net_bind_service)
    # Allow telegraf to read MSR value to get intel_powerstat plugin metrics (cap_sys_rawio,cap_dac_read_search)
    setcap cap_net_raw,cap_net_bind_service,cap_sys_rawio,cap_dac_read_search+ep /usr/bin/telegraf || echo "Failed to set additional capabilities on /usr/bin/telegraf"

    exec su-exec telegraf "$@"
fi
