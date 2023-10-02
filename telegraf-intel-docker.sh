#!/bin/bash

set -eo pipefail

IFS=$'\n\t'

DOCKER_CONTAINER_NAME=$3
DOCKER_DPDK_SOCKET_PATH="/var/run/dpdk/rte"
DOCKER_LIBVIRT_SOCKET_PATH="/var/run/libvirt/libvirt-sock"
DOCKER_LIBVIRT_TLS_CERT="/etc/pki/CA"
DOCKER_P4RUNTIME_TLS_CERT="/etc/pki/CA"
DOCKER_SSH_DIR="$HOME/.ssh"
DOCKER_PMU_EVENTS_PATH="/var/cache/pmu"
DOCKER_INTEL_BASEBAND_LOG=""
DOCKER_INTEL_BASEBAND_SOCKET=""

readonly TELEGRAF_VERSION='1.27.4-alpine'

readonly DOCKER_IMAGE_NAME=$2
readonly DOCKER_IMAGE_TAG='1.3.0'
readonly DOCKER_TELEGRAF_BUILD_IMAGE="telegraf:${TELEGRAF_VERSION}"
readonly DOCKER_TELEGRAF_FINAL_BASE_IMAGE='alpine:3.18'

readonly CONTAINER_MEMORY_LIMIT=200m
readonly CONTAINER_CPU_SHARES=512

readonly YELLOW='\033[1;33m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
readonly NO_COLOR='\033[0m'

# Check docker presents on machine.
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

# Build docker image.
function build_docker() {
  echo -e "${GREEN}Building Telegraf Docker image...${NO_COLOR}"
  echo -e "Using telegraf version: ${TELEGRAF_VERSION}. Final base image: ${DOCKER_TELEGRAF_FINAL_BASE_IMAGE}"
  echo "If this is your first time building image this might take a minute..."
  docker build --build-arg TELEGRAF_TAG=$TELEGRAF_VERSION --build-arg FINAL_BASE_IMAGE=$DOCKER_TELEGRAF_FINAL_BASE_IMAGE -f images/telegraf/Dockerfile . -t "$DOCKER_IMAGE_NAME":$DOCKER_IMAGE_TAG
}

# Build and run docker container.
function run_docker() {
  DOCKER_MOUNT_VARIABLES_ARRAY=(-v "$(pwd)/telegraf/:/etc/telegraf/:ro" \
  -v "/sys/kernel/debug:/sys/kernel/debug:ro" \
  -v "/sys/fs/resctrl:/sys/fs/resctrl:rw" \
  -v "/proc:/hostfs/proc:ro" \
  -v "/run/udev:/run/udev:ro" \
  -v "/var/run/utmp:/var/run/utmp:ro" \
  -v "/sys/devices:/sys/devices:ro" \
  -v "/dev/cpu:/dev/cpu:ro" \
  -v "/sys/fs/cgroup:/sys/fs/cgroup:ro" \
  -v "${DOCKER_LIBVIRT_SOCKET_PATH}:${DOCKER_LIBVIRT_SOCKET_PATH}" \
  -v "${DOCKER_SSH_DIR}:${DOCKER_SSH_DIR}" \
  -v "${DOCKER_LIBVIRT_TLS_CERT}:${DOCKER_LIBVIRT_TLS_CERT}" \
  -v "${DOCKER_P4RUNTIME_TLS_CERT}:${DOCKER_P4RUNTIME_TLS_CERT}" \
  -v "${DOCKER_DPDK_SOCKET_PATH}:${DOCKER_DPDK_SOCKET_PATH}:ro" \
  -v "${DOCKER_PMU_EVENTS_PATH}:${DOCKER_PMU_EVENTS_PATH}:ro")

  if [ "$USE_HOST_RASDAEMON" == "true" ]; then
    DOCKER_MOUNT_VARIABLES_ARRAY=("${DOCKER_MOUNT_VARIABLES_ARRAY[@]}" -v "/var/lib/rasdaemon/ras-mc_event.db:/var/lib/rasdaemon/ras-mc_event.db:ro")
  fi

  if [ "${DOCKER_INTEL_BASEBAND_LOG}" != "" ] && [ "${DOCKER_INTEL_BASEBAND_SOCKET}" != "" ]; then
    DOCKER_MOUNT_VARIABLES_ARRAY=("${DOCKER_MOUNT_VARIABLES_ARRAY[@]}" \
    --mount "type=bind,source=${DOCKER_INTEL_BASEBAND_LOG},target=${DOCKER_INTEL_BASEBAND_LOG}" \
    --mount "type=bind,source=${DOCKER_INTEL_BASEBAND_SOCKET},target=${DOCKER_INTEL_BASEBAND_SOCKET}")
  fi

  docker run -d --hostname telegraf-intel \
            --name "$DOCKER_CONTAINER_NAME" \
            "${DOCKER_MOUNT_VARIABLES_ARRAY[@]}" \
            --network=host \
            --privileged \
            -e HOSTNAME="telegraf-intel" \
            -e HOST_PROC=/hostfs/proc \
            -e HOST_MOUNT_PREFIX=/hostfs \
            --memory="$CONTAINER_MEMORY_LIMIT" \
            --cpu-shares="$CONTAINER_CPU_SHARES" \
            --restart on-failure:5 \
            --health-cmd='stat /etc/passwd || exit 1' \
            --pids-limit 1024 \
            -i -t "$DOCKER_IMAGE_NAME":$DOCKER_IMAGE_TAG
}

# Remove docker images
function remove_docker_images() {
  echo -e "${YELLOW}Removing Telegraf Docker image...${NO_COLOR}"
  docker rmi "$DOCKER_IMAGE_NAME":$DOCKER_IMAGE_TAG
  # Remove images used in multistage build to build final image.
  echo -e "${YELLOW}Removing Telegraf Docker image used in multistage build...${NO_COLOR}"
  docker rmi $DOCKER_TELEGRAF_BUILD_IMAGE
  docker rmi $DOCKER_TELEGRAF_FINAL_BASE_IMAGE
  echo -e "${YELLOW}Removing dangling images${NO_COLOR}"
  # Suppress warning for double quoting this command. When it's quoted it won't remove all dangling images.
  # shellcheck disable=SC2046
  docker rmi $(docker images -f "dangling=true" -q)
}

# Check third argument presence for build-run and similar options.
function check_third_arg_presence() {
  if [ $# -gt 2 ]; then
    return 0
  else
    echo -e "${RED}Please provide image and container name! e.g.: ${YELLOW}./telegraf-intel-docker.sh build-run my-img my-container${NO_COLOR}"
    return 1
  fi
}

# Check number of arguments, if second argument is present then return true.
function check_arg_number() {
  if [ $# -gt 2 ]; then
    echo -e "${RED}Too many arguments were given.${NO_COLOR}"
    return 1
  elif [ $# -eq 2 ]; then
    DOCKER_CONTAINER_NAME=$2
    return 0
  else
    echo -e "${RED}Please provide container name! e.g.: ${YELLOW}./telegraf-intel-docker.sh enter my-container${NO_COLOR}"
    return 1
  fi
}

# Check if container name exist is listed in docker container list, if so return true.
function check_container_name() {
  if [ "$(docker ps -a -q -f name="^/$DOCKER_CONTAINER_NAME$")" ]; then
    return 0
  else
    return 1
  fi
}


function check_flag_presence() {
  # Example of command line arguments:
  # <1: docker command, for example: build-run> <2: image-name> <3: container-name>
  # <4: dpdk_socket_path / use-host-rasdaemon / pmu_events / libvirt_socket_path / p4runtime_socket_path > <5:value>

  # Shift the first three command line arguments since they are not needed.
  shift 3

  # Loop over the remaining command line arguments.
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dpdk_socket_path)
        # If the argument is --dpdk_socket_path, shift again to get the value of the flag,
        # check if the provided directory exists, set DOCKER_DPDK_SOCKET_PATH to the path of the dir.
        shift
        if [ ! -d "$1" ]; then
          echo -e "${RED}Cannot find provided directory - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_DPDK_SOCKET_PATH=$1
        ;;
      --use-host-rasdaemon)
        # If the argument is --use-host-rasdaemon, set USE_HOST_RASDAEMON to true
        # Print a message indicating that the function is mounting a folder from the host OS.
        echo -e "${YELLOW}Mounting rasdaemon folder from host OS${NO_COLOR}"
        USE_HOST_RASDAEMON=true
        ;;
      --pmu_events)
        # If the argument is --pmu_events, shift again to get the value of the flag
        # Check if the provided directory exists, set DOCKER_PMU_EVENTS_PATH to the path of the directory.
        shift
        if [ ! -d "$1" ]; then
          echo -e "${RED}Cannot find provided directory - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_PMU_EVENTS_PATH=$1
        ;;
      --libvirt_socket_path)
        # If the argument is --libvirt_socket_path, shift again to get the value of the flag
        # Check if the provided file exists and is a socket file, set DOCKER_LIBVIRT_SOCKET_PATH to the path of the file.
        echo "Changing default libvirt socket path - $DOCKER_LIBVIRT_SOCKET_PATH to $1"
        shift
        if [ ! -S "$1" ]; then
          echo -e "${RED}Cannot find provided file - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_LIBVIRT_SOCKET_PATH=$1
        ;;
      --ssh_dir)
        # If the argument is --ssh_dir, shift again to get the value of the flag
        # Check if the provided file exists and is a directory, set DOCKER_SSH_DIR to the path of the dir.
        shift
        echo "Changing default ssh dir - $DOCKER_SSH_DIR to $1"
        if [ ! -d "$1" ]; then
          echo -e "${RED}Cannot find provided directory - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_SSH_DIR=$1
        ;;
      --libvirt_tls_cert)
        # If the argument is --libvirt_tls_cert, shift again to get the value of the flag
        # Check if the provided file exists and is a directory, set DOCKER_LIBVIRT_TLS_CERT to the path of the dir.
        shift
        echo "Changing default libvirt tls dir - $DOCKER_LIBVIRT_TLS_CERT to $1"
        if [ ! -d "$1" ]; then
          echo -e "${RED}Cannot find provided directory - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_LIBVIRT_TLS_CERT=$1
        ;;
      --p4runtime_tls_cert)
        # If the argument is --p4runtime_tls_cert, shift again to get the value of the flag
        # Check if the provided file exists and is a directory, set DOCKER_P4RUNTIME_TLS_CERT to the path of the dir.
        shift
        echo "Changing default p4runtime tls dir - $DOCKER_P4RUNTIME_TLS_CERT to $1"
        if [ ! -d "$1" ]; then
          echo -e "${RED}Cannot find provided directory - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_P4RUNTIME_TLS_CERT=$1
        ;;
      --intel_baseband_socket_path)
        # If the argument is --intel_baseband_socket_path, shift again to get the value of the flag
        # Check if the provided file exists and is a socket file, set DOCKER_INTEL_BASEBAND_SOCKET to the path of the file.
        shift
        if [ ! -S "$1" ]; then
          echo -e "${RED}Cannot find provided file - $1${NO_COLOR}"
          exit 1
        fi
        DOCKER_INTEL_BASEBAND_SOCKET=$1
        ;;
     --intel_baseband_log_path)
       # If the argument is --intel_baseband_log_path, shift again to get the value of the flag
       # Check if the provided file exists and is a regular file, set DOCKER_INTEL_BASEBAND_LOG to the path of the file.
       shift
       if [ ! -f "$1" ]; then
         echo -e "${RED}Cannot find provided file - $1${NO_COLOR}"
         exit 1
       fi
       DOCKER_INTEL_BASEBAND_LOG=$1
       ;;
      *)
        # If the argument is none of the above, print an error message and exit with a status of 1.
        echo -e "${RED}Unknown command - '$1'${NO_COLOR}"
        exit 1
        ;;
    esac
    # Shift the arguments again to move to the next one.
    shift
  done
}

telegraf-intel-docker() {
  # Enter attaches users to a shell in the desired container.
  enter() {
    if check_arg_number "$@"; then
      echo -e "${YELLOW}Entering /bin/bash session in the telegraf container...${NO_COLOR}"
      docker exec -u telegraf -i -t "$DOCKER_CONTAINER_NAME" /bin/bash
    fi
  }

  # Logs streams the logs from the container to the shell.
  logs() {
    if check_arg_number "$@"; then
      echo -e "${YELLOW}Following the logs from the telegraf container...${NO_COLOR}"
      docker logs -f --since=1s "$DOCKER_CONTAINER_NAME"
    fi
  }

  case $1 in
  build-run)
    if check_third_arg_presence "$@"; then
      # Check if there is container if same name as user gave in argument
      if ! check_container_name; then
        check_flag_presence "$@"
        # Build image with set TELEGRAF_TAG argument that specify telegraf version.
        # Alpine version has lowest memory usage.
        build_docker
        # Build container and run it in background, with mounted files, in privileged mode, shared network with host, and with runtime environment variables.
        run_docker
        echo -e "${GREEN}DONE!${NO_COLOR}"
      else
        echo -e "${RED}Container with name '${DOCKER_CONTAINER_NAME}' already exists. Please provide new one.${NO_COLOR}"
      fi
    fi
    ;;
  build)
    if check_arg_number "$@"; then
      # Build image with set TELEGRAF_TAG argument that specify telegraf version.
      # Alpine version has lowest memory usage.
      build_docker
      echo -e "${GREEN}DONE!${NO_COLOR}"
    fi
    ;;
  run)
    if check_third_arg_presence "$@"; then
      if [ "$(docker images -a -q "$DOCKER_IMAGE_NAME")" ]; then
        check_flag_presence "$@"
        echo -e "${GREEN}Running Telegraf Docker container...${NO_COLOR}"
        run_docker
        echo -e "${GREEN}DONE!${NO_COLOR}"
      else
        echo -e "${RED}Image with name '${DOCKER_IMAGE_NAME}' not exists. Please provide correct name.${NO_COLOR}"
      fi

    fi
    ;;
  restart)
    if check_third_arg_presence "$@"; then
      # Check if there is container with name telegraf, to prevent restarting not existing container.
      if [ "$(docker ps -a -q -f name="$DOCKER_CONTAINER_NAME")" ]; then
        echo -e "${YELLOW}Rebuilding Telegraf Docker image...${NO_COLOR}"
        # Rebuild image.
        build_docker
        echo -e "${YELLOW}Restarting Telegraf Docker container...${NO_COLOR}"
        # Restart container, to use latest build image.
        docker restart "$DOCKER_CONTAINER_NAME"
        echo -e "${GREEN}Done!${NO_COLOR}"
      else
        echo -e "${YELLOW}There's no Telegraf Docker CONTAINER/IMAGE with name '${DOCKER_CONTAINER_NAME}'/
        '${DOCKER_IMAGE_NAME}', please build and run image using: ${NO_COLOR}./telegraf-intel-docker build-run <image-name> <container-name>"
      fi
    fi
    ;;
  remove)
    if check_third_arg_presence "$@"; then
      echo -e "${YELLOW}Stopping Telegraf Docker container...${NO_COLOR}"
      docker stop "$DOCKER_CONTAINER_NAME"
      echo -e "${YELLOW}Removing Telegraf Docker container...${NO_COLOR}"
      docker rm "$DOCKER_CONTAINER_NAME"
      remove_docker_images
    fi
    ;;
  remove-build)
    if check_arg_number "$@"; then
      remove_docker_images
    fi
    ;;
  enter)
    enter "$@"
    ;;
  logs)
    logs "$@"
    ;;
  *)
    cat <<-EOF
telegraf dockerized commands:

  build <image-name>                                         -> Build Telegraf Docker image.

  build-run <image-name> <container-name>                    -> Build and run Telegraf Docker image.
     options:
        --pmu_events <events definition path>                -> Path to filesystem directory containing JSON files with PMU events definitions. Default: "/var/cache/pmu"
        --dpdk_socket_path <dpdk socket path>                -> Path to DPDK socket (if needed). Default: "/var/run/dpdk/rte"
        --use-host-rasdaemon                                 -> Mount rasdaemon folder from host OS.
        --ssh_dir                                            -> Path to .ssh dir. Default: "\$HOME/.ssh"
        --libvirt_socket_path                                -> Path to libvirt socket. Default: "/var/run/libvirt/libvirt-sock"
        --libvirt_tls_cert                                   -> Path to dir with libvirt tls certs. Default: "/etc/pki/CA"
        --p4runtime_tls_cert                                 -> Path to dir with p4runtime tls certs. Default: "/etc/pki/CA"

  run <image-name> <container-name>                          -> Run Telegraf Docker image.
     options:
        --pmu_events <events definition path>                -> Path to filesystem directory containing JSON files with PMU events definitions. Default: "/var/cache/pmu"
        --dpdk_socket_path <dpdk socket path>                -> Path to DPDK socket (if needed). Default: "/var/run/dpdk/rte"
        --use-host-rasdaemon                                 -> Mount rasdaemon folder from host OS.
        --ssh_dir                                            -> Path to .ssh dir. Default: "\$HOME/.ssh"
        --libvirt_socket_path                                -> Path to libvirt socket. Default: "/var/run/libvirt/libvirt-sock"
        --libvirt_tls_cert                                   -> Path to dir with libvirt tls certs. Default: "/etc/pki/CA"
        --p4runtime_tls_cert                                 -> Path to dir with p4runtime tls certs. Default: "/etc/pki/CA"

  restart <image-name> <container-name>                      -> Restart Telegraf image and container.

  remove  <image-name> <container-name>                      -> Stop and remove ALL Telegraf Docker containers, and images.

  remove-build <container-name>                              -> Remove all multistage images, and Telegraf Intel Docker image.

  enter <container-name>                                     -> Enter Telegraf Docker CONTAINER via bash.

  logs  <container-name>                                     -> Stream logs for the Telegraf Docker container.

EOF
    ;;
  esac
}

pushd "$(dirname "$0")" >/dev/null
telegraf-intel-docker "$@"
popd >/dev/null
