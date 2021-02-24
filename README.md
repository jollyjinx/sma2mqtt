#Swift Package to read Speedwire from SunnyHomeManager and publish them over MQTT inside docker on raspberry ARM64

The build.sh is a build script to create a docker container to compile and run the actual swift program inside the container.
It's hacked been together to see if a swift program is feasable and doable at all on linux inside a docker container.
It uses docker network to connect to the correct VLAN my network is heavily split up in different VLANs. The swift program will accept the IP to listen on for the Multicast address that it's joining.

What you need to adjust: 

## main.swift:
mqtt host: is named *mqtt* in my case (my mqtt docker container is named mqtt inside a docker named mqtt-net network)
mqtt topic: is named *sma/sunnymanager* here.
