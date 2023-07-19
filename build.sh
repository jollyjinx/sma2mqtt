#!/bin/bash
#
# This script downloads the current docker container
# and starts it with autorestart.
# I use this script on a raspberry pi running ubuntu
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

docker run \
        --detach --restart=always \
        --net service16 \
        --log-opt max-size=1m --log-opt max-file=2 \
        --name "$programname" \
        "$version" "$programname" --inverter-password "$INVERTER_PASSWORD"

#docker network connect mqtt-net "$programname"
