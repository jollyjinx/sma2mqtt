FROM th089/swift:latest
#FROM helje5/arm64v8-swift

WORKDIR /home

CMD ["./build/buildandstart.sh"]

