#!/bin/bash

set -eo pipefail

IFS=$'\n\t'

DOCKER_CONTAINER_NAME=$3
DOCKER_DPDK_SOCKET_PATH="/var/run/dpdk/rte"
DOCKER_PMU_EVENTS_PATH="/var/cache/pmu"

readonly TELEGRAF_VERSION='1.24.3-alpine'

readonly DOCKER_IMAGE_NAME=$2
readonly DOCKER_IMAGE_TAG='1.2.0'
readonly DOCKER_TELEGRAF_BUILD_IMAGE="telegraf:${TELEGRAF_VERSION}"
readonly DOCKER_TELEGRAF_FINAL_BASE_IMAGE='alpine:3.16'

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
  -v "${DOCKER_DPDK_SOCKET_PATH}:${DOCKER_DPDK_SOCKET_PATH}:ro" \
  -v "${DOCKER_PMU_EVENTS_PATH}:${DOCKER_PMU_EVENTS_PATH}:ro")

  if [ "$USE_HOST_RASDAEMON" == "true" ]; then
    DOCKER_MOUNT_VARIABLES_ARRAY=("${DOCKER_MOUNT_VARIABLES_ARRAY[@]}" -v "/var/lib/rasdaemon:/var/lib/rasdaemon:ro")
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
            --security-opt=no-new-privileges \
            --pids-limit 100 \
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
  flags_array=( "$@" )
  for (( i=3; i<$#; i++)) do
    case "${flags_array[$i]}" in
    "--dpdk_socket_path")
      i=$((i+1))
      if [ -f "${flags_array[$i]}" ]; then
        # Set docker path from argument provided by user
        DOCKER_DPDK_SOCKET_PATH="${flags_array[$i]}"
        continue
      else
        echo -e "${RED}Can not find provided file - ${flags_array[$i]} ${NO_COLOR}"
        exit 1
      fi
      ;;
    "--use-host-rasdaemon")
      echo -e "${YELLOW}Mounting rasdaemon folder from host OS${NO_COLOR}"
      USE_HOST_RASDAEMON="true"
      continue
      ;;
    "--pmu_events")
      i=$((i+1))
      if [ -d "${flags_array[$i]}" ]; then
        DOCKER_PMU_EVENTS_PATH="${flags_array[$i]}"
        continue
      else
        echo -e "${RED}Can not find provided directory - ${flags_array[$i]} ${NO_COLOR}"
        exit 1
      fi
    ;;
    *)
      echo -e "${RED}Unknown command - '${flags_array[$i]}'${NO_COLOR}"
      exit 1
      ;;
    esac
  done
}

telegraf-intel-docker() {
  # Enter attaches users to a shell in the desired container.
  enter() {
    if check_arg_number "$@"; then
      echo -e "${YELLOW}Entering /bin/bash session in the telegraf container...${NO_COLOR}"
      docker exec -i -t "$DOCKER_CONTAINER_NAME" /bin/bash
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

  run <image-name> <container-name>                          -> Run Telegraf Docker image.
     options:
        --pmu_events <events definition path>                -> Path to filesystem directory containing JSON files with PMU events definitions. Default: "/var/cache/pmu"
        --dpdk_socket_path <dpdk socket path>                -> Path to DPDK socket (if needed). Default: "/var/run/dpdk/rte"
        --use-host-rasdaemon                                 -> Mount rasdaemon folder from host OS.

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
