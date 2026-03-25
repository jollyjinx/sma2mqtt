#!/bin/bash
#
# Starts the published `sma2mqtt` container locally.
#
# Purpose:
# - stop and remove any existing `sma2mqtt` container
# - pull/run the configured image tag
# - launch it in detached mode with automatic restart enabled
#
# Typical use:
# - run this on the target host that should keep `sma2mqtt` running
# - set `INVERTER_PASSWORD` below before using it
#
# Notes:
# - the script must run as a regular user, not as root
# - it expects Docker to be installed and the `service16` network to exist
# - by default it runs the `latest` image from Docker Hub
#

INVERTER_PASSWORD="MyPassword"


if [[ $EUID -eq 0 ]]; then
   echo "This script must NOT run as root"
   exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}

programname=sma2mqtt
docker stop $programname
docker container rm $programname

version="jollyjinx/$programname:latest"
#version="jollyjinx/$programname:development"

DOCKER_UID=$(id -u ${USER})
DOCKER_GID=$(id -g ${USER})

docker run \
        --detach --restart=always \
        -u $DOCKER_UID:$DOCKER_GID \
        --net service16 \
        --log-opt max-size=1m --log-opt max-file=2 \
        --name "$programname" \
        "$version" "$programname" --inverter-password "$INVERTER_PASSWORD"

#docker network connect mqtt-net "$programname"
