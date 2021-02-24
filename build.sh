#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "DIR:$DIR"

cd ${DIR}

buildpath=.build
name=$(perl -ne  'BEGIN{ $/=undef; } print "$1\n" if /Package\(\s+name\:\s+\"(.*?)\"/;' <Package.swift)

if [[ -z $name ]]
then
    echo "Could not find destination name in Package.swift"
    exit 1
fi

mkdir ${buildpath}
cat >${buildpath}/buildandstart.sh <<EOF
#!/bin/sh
swift build -c release --build-path=${buildpath}
exec ${buildpath}/release/${name}

EOF
chmod ugo+x ${buildpath}/buildandstart.sh

cat >Dockerfile <<EOF
FROM th089/swift:latest

WORKDIR /home

CMD ["${buildpath}/buildandstart.sh"]

EOF

docker image inspect swift:latest || docker build -t swift:latest .

docker stop $name
docker container rm $name

docker run \
        --detach --restart=always \
        -u $(id -u ${USER}):$(id -g ${USER}) \
        --net service16 \
        --log-opt max-size=1m --log-opt max-file=2 \
        -v ${DIR}/:/home \
        --name $name \
        swift:latest
docker network connect mqtt-net $name
