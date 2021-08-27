# SMA SpeedWire and Home Manager

Tools to get SMA live data feed published to MQTT.

## sma2mqtt

__sma2mqtt__ reads data from Sunny HomeManager and publishes the data to MQTT.
__sma2mqtt__ joins the SMA multicast and listens to the announcements that Sunny HomeManager does in that group. It works only inside the local network as multicast only works there.

Inside the repository is a *build.sh* shell script that creates a docker container with *sma2mqtt* inside. You need to adjust it to your needs, as your docker setup is probably different than mine.

Output of __sma2mqtt__ will look like this on a mqtt broker:

![SunnyManager mqtt example](Images/sunnymanager.mqtt.png)


## Future

I use __sma2mqtt__ in 'production' and it works fine. Inverter values are currently read out via modbus, but I started reversing the [SMA inverter protocol](SMA%20Protocol.md) to get sma2mqtt read values from all SMA prodcuts via UDP. Modbus seems to have problems on SMA inverters, that's why I want to switch.

### Usage


```
USAGE: sma2mqtt [--debug ...] [--json] [--mqtt-servername <mqtt-servername>] [--mqtt-port <mqtt-port>] [--interval <interval>] [--topic <topic>] [--bind-address <bind-address>] [--bind-port <bind-port>] [--mcast-address <mcast-address>] [--mcast-port <mcast-port>]

OPTIONS:
  -d, --debug             optional debug output 
  --json                  send json output to stdout 
  --mqtt-servername <mqtt-servername>
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
{
  "id": "1:4.4.0",
  "title": "Reactive Feedin",
  "topic": "immediate/reactivefeedin",
  "value": 103.4,
  "unit": "W"
}
{
  "id": "1:4.8.0",
  "title": "Reactive Feedin Counter",
  "topic": "counter/reactivefeedin",
  "value": 3544.3821,
  "unit": "kWh"
}
{
  "id": "1:9.4.0",
  "title": "Apparent Usage",
  "topic": "immediate/apparentusage",
  "value": 104.8,
  "unit": "W"
}
{
  "id": "1:9.8.0",
  "title": "Apparent Usage Counter",
  "topic": "counter/apparentusage",
  "value": 4246.7811,
  "unit": "kWh"
}
.
.
.
```


