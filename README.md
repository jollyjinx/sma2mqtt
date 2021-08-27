# SMA SpeedWire and Home Manager

Tools to get SMA live data feed published to MQTT.

## sma2mqtt

*sma2mqtt* currently publishes HomeManager data to MQTT. 
The build.sh is a build script to create a docker container to compile and run the actual swift program inside the container. It's been hacked together to see if a swift program is feasable and doable at all, on linux inside a docker container. It uses docker network to connect to the correct VLAN - my network is heavily split up in different VLANs. 

*sma2mqtt* reads data via joining the SMA multicast group (so it currently works only inside the local network). 

On the mqtt broker it will look like this:

![SunnyManager mqtt example](Images/sunnymanager.mqtt.png)


I started reversing the [SMA inverter protocol](SMA%20Protocol.md) to get sma2mqtt read values from all SMA prodcuts and publish them on MQTT.

### Usage


```
USAGE: sma2mqtt [--debug ...] [--json] [--mqqt-servername <mqqt-servername>] [--mqtt-port <mqtt-port>] [--interval <interval>] [--topic <topic>] [--bind-address <bind-address>] [--bind-port <bind-port>] [--mcast-address <mcast-address>] [--mcast-port <mcast-port>]

OPTIONS:
  -d, --debug             optional debug output 
  --json                  send json output to stdout 
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


### Example 

Start with --json option which will print the json that is sent to the mqtt server to stdout. jq is used just for formatting.
```
$./sma2mqtt --json |jq . 
[
  {
    "unit": "W",
    "devicename": "sunnymanager",
    "id": "1:1.4.0",
    "time": "2021-08-07 07:58:31 +0000",
    "title": "Grid Usage",
    "payload": 0,
    "topic": "sums",
    "value": 0,
    "name": "usage"
  },
  {
    "unit": "Ws",
    "devicename": "sunnymanager",
    "id": "1:1.8.0",
    "time": "2021-08-07 07:58:31 +0000",
    "title": "Grid Usage Counter",
    "payload": 2961.7594,
    "topic": "sums",
    "value": 2961.7594,
    "name": "usagecounter"
  },
  {
    "unit": "W",
    "devicename": "sunnymanager",
    "id": "1:2.4.0",
    "time": "2021-08-07 07:58:31 +0000",
    "title": "Grid Feedin",
    "payload": 2902.5,
    "topic": "sums",
    "value": 2902.5,
    "name": "feedin"
  },
  {
    "unit": "Ws",
    "devicename": "sunnymanager",
    "id": "1:2.8.0",
    "time": "2021-08-07 07:58:31 +0000",
    "title": "Grid Feedin Counter",
    "payload": 7655.8808,
    "topic": "sums",
.
.
.
```


