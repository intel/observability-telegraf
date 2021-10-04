#!/bin/bash

set -eo pipefail

IFS=$'\n\t'

DOCKER_CONTAINER_NAME=$3
DOCKER_DPDK_SOCKET_PATH="/var/run/dpdk/rte"

readonly TELEGRAF_VERSION='1.19-alpine'

readonly DOCKER_IMAGE_NAME=$2
readonly DOCKER_IMAGE_TAG='0.2'
readonly DOCKER_TELEGRAF_BUILD_IMAGE='telegraf:1.19-alpine'
readonly DOCKER_TELEGRAF_FINAL_BASE_IMAGE='alpine:3.14.2'

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
  echo "If this is your first time building image this might take a minute..."
  docker build --build-arg TELEGRAF_TAG=$TELEGRAF_VERSION -f images/telegraf/Dockerfile . -t "$DOCKER_IMAGE_NAME":$DOCKER_IMAGE_TAG
}

# Build and run docker container.
function run_docker() {
  docker run -d --hostname telegraf-intel \
    --name "$DOCKER_CONTAINER_NAME" \
    -v "$PWD"/telegraf/:/etc/telegraf/:ro \
    -v /sys/kernel/debug:/sys/kernel/debug:ro \
    -v /sys/fs/resctrl:/sys/fs/resctrl:rw \
    -v /proc/self/mounts:/hostfs/proc/self/mounts:ro \
    -v /proc/diskstats:/hostfs/proc/diskstats:ro \
    -v /run/udev:/run/udev:ro \
    -v /var/run/utmp:/var/run/utmp:ro \
    -v "$DOCKER_DPDK_SOCKET_PATH":/var/run/dpdk/rte:ro \
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
  if [ $# -eq 2 ]; then
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

# Apply DPDK socket variable if needed
function check_flag_presence() {
  # Check flag presence
  if [ $# -ge 4 ]; then
    if [ "$4" == "--dpdk_socket_path" ]; then
      # If last argument is empty throw error.
      if [ -z "$5" ]; then
        echo -e "${RED}Please provide DPDK socket path, e.g.: ./telegraf-intel-docker.sh build-run img container --dpdk_socket_path /var/run/dpdk/rte${NO_COLOR}"
        exit 1
      else
        # Set docker path from argument provided by user
        DOCKER_DPDK_SOCKET_PATH=$5
      fi
    else
      echo -e "${RED}Flag '${4}' not found.${NO_COLOR}"
      exit 1
    fi
  fi
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
        # Build image with set TELEGRAF_TAG argument that specify telegraf version.
        # Alpine version has lowest memory usage.
        build_docker
        # Build container and run it in background, with mounted files, in privileged mode, shared network with host, and with runtime environment variables.
        check_flag_presence "$@"
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
        echo -e "${GREEN}Running Telegraf Docker container...${NO_COLOR}"
        check_flag_presence "$@"
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

  build-run <image-name> <container-name>                                  -> Build and run Telegraf Docker image.

  build-run <image-name> <container-name> --dpdk_socket_path <dpdk socket path>  -> Build and run Telegraf Docker image, with path to DPDK socket (if needed).

  build <image-name>                                                       -> Build Telegraf Docker image.

  run <image-name> <container-name>                                        -> Run Telegraf Docker image.

  run <image-name> <container-name> --dpdk_socket_path <dpdk socket path>  -> Run Telegraf Docker image, with path to DPDK socket (if needed).

  restart <image-name> <container-name>                                    -> Restart Telegraf image and container.

  remove <image-name> <container-name>                                     -> Stop and remove ALL Telegraf Docker containers, and images.

  remove-build <container-name>                                            -> Remove all multistage images, and Telegraf Intel Docker image.

  enter <container-name>                                                   -> Enter Telegraf Docker CONTAINER via bash.

  logs <container-name>                                                    -> Stream logs for the Telegraf Docker container.

EOF
    ;;
  esac
}

pushd "$(dirname "$0")" >/dev/null
telegraf-intel-docker "$@"
popd >/dev/null
