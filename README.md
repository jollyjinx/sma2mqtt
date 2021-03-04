# sma2mqtt
Swift Package to read Speedwire from SunnyHomeManager and publish them over MQTT inside docker on raspberry ARM64

The build.sh is a build script to create a docker container to compile and run the actual swift program inside the container. It's been hacked together to see if a swift program is feasable and doable at all, on linux inside a docker container.

It uses docker network to connect to the correct VLAN - my network is heavily split up in different VLANs. 

If you want to change things - here we go

```
USAGE: sma2mqtt [--debug] [--mqqt-servername <mqqt-servername>] [--mqtt-port <mqtt-port>] [--interval <interval>] [--topic <topic>] [--bind-address <bind-address>] [--bind-port <bind-port>] [--mcast-address <mcast-address>] [--mcast-port <mcast-port>]

OPTIONS:
  -d, --debug             optional debug output 
  --mqqt-servername <mqqt-servername>
                          MQTT Server hostname (default: mqtt)
  --mqtt-port <mqtt-port> MQTT Server port (default: 1883)
  -i, --interval <interval>
                          Interval to send updates to mqtt Server. (default: 1.0)
  -t, --topic <topic>     MQTT Server topic. (default: sma/sunnymanager)
  --bind-address <bind-address>
                          Multicast Binding Listening Interface Address. (default: 0.0.0.0)
  --bind-port <bind-port> Multicast Binding Listening Port number. (default: 0)
  --mcast-address <mcast-address>
                          Multicast Group Address. (default: 239.12.255.254)
  --mcast-port <mcast-port>
                          Multicast Group Port number. (default: 9522)
  -h, --help              Show help information.
```
