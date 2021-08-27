#!/bin/bash

if [[ $EUID -eq 0 ]]; then
   echo "This script must NOT run as root"
   exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "DIR:$DIR"
cd ${DIR}


packagedir="$DIR/sma2mqtt"
buildpath=.build
programname=sma2mqtt
releasepath=release
if [[ ! -d "$packagedir" ]];
then
	echo "$packagedir does not exist."
	exit 1
fi

cd "$packagedir"
mkdir "$buildpath"    2>/dev/null

cat >"buildandstart.sh" <<EOF
#!/bin/bash

executable="$buildpath/$releasepath/$programname"
if [[ ! -x "\$executable" ]];
then
	echo "Did not find executable \$executable - building"
	swift build -c release --build-path="$buildpath"
fi
echo "Executing \$executable"
exec "\$executable" --interval 10
EOF

chmod ugo+x "buildandstart.sh"

cat >Dockerfile <<EOF
FROM swiftarm/swift:latest
WORKDIR /home
CMD ["/home/buildandstart.sh"]
EOF

docker build -t swift:latest .

# docker image inspect swift:latest >/dev/null 2>/dev/null  || docker build -t swift:latest .

docker stop $programname
docker container rm $programname

        #-u $(id -u ${USER}):$(id -g ${USER}) \

docker run \
        --detach --restart=always \
        --net service16 \
        --log-opt max-size=1m --log-opt max-file=2 \
        -v "$packagedir":/home \
        --name "$programname" \
        swift:latest

docker network connect mqtt-net "$programname"
