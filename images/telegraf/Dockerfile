# MIT License
# 
# Copyright (c) 2021 Intel Corporation
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 

ARG TELEGRAF_TAG
FROM telegraf:$TELEGRAF_TAG AS builder

RUN apk update && \
    apk add --update --no-cache \
    zlib=~1.2.12 \
    build-base=~0.5 \
    bash=~5.1 \
    sudo=~1.9 \
    git=~2.34 \
    alpine-sdk=~1.0 \
    libffi-dev=~3.4 \
    openssl-dev=~1.1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR "/telegraf_docker/"

COPY ./images/telegraf/script/install_intel_cmt_cat.sh ./

RUN ./install_intel_cmt_cat.sh

# Build final image where telegraf is running.
FROM alpine:3.15.0

RUN export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" && \
    apk update && \
    apk add --update --no-cache \
    zlib=~1.2.12 \
    util-linux=~2.37 \
    bash=~5.1 \
    sudo=~1.9 \
    smartmontools=~7.2 \
    nvme-cli=~1.16 \
    rasdaemon=~0.6 \
    iptables=~1.8 \
    ipmitool=~1.8 \
    su-exec=~0.2 \
    iputils=~20210722 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR "/telegraf_docker/"

COPY ./images/telegraf/script/sudo_configuration.sh .
COPY ./DEPENDENCIES_SOURCE_CODE_INFO.md .

# Copy dependecies from previous step called builder, where intel-cmt-cat is installed.
COPY --from=builder /usr/local/lib/libpqos.* /usr/lib/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/share/snmp/mibs/ /usr/share/snmp/mibs/
COPY --from=builder /usr/bin/telegraf /usr/bin/telegraf
COPY --from=builder entrypoint.sh .

# Set sudo config for specific plugins, and just in case update alternatives, because sometimes docker can mess it up.
RUN ./sudo_configuration.sh

# Override entrypoint
ENTRYPOINT ["sh", "-c", "rasdaemon -r && sleep 10s && ./entrypoint.sh telegraf"]
