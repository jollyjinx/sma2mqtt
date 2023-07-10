# SMA SpeedWire and Home Manager

Tools to get SMA live data feed published to MQTT.

## sma2mqtt

__sma2mqtt__ recognizes SMA devices in the local network (inverters and Sunny HomeManager) find out which data are there to be published and publishes the data to a mqtt server.
__sma2mqtt__ joins the SMA multicast and listens to the announcements that Sunny HomeManager does in that group. It works only inside the local network as multicast only works there.

Inside the repository is a *build.sh* shell script that creates a docker container with __sma2mqtt__ inside. You need to adjust it to your needs, as your docker setup is probably different than mine.

Output of __sma2mqtt__ will look like this on a mqtt broker:

<img src="Images/sunnymanager.mqtt.long.png" width="50%" alt="SunnyManager mqtt example"/>

## Docker usage

I've built an docker image for a raspberry pi which you can directly use:
```
docker run --name "sma2mqtt" --net service16  jollyjinx/sma2mqtt:latest sma2mqtt --inverter-password MySimplePassword --log-level
```
I'm using *--net* option here as I'm using a seperate network for my sma devices. Otherwise you need to open port 9522 for the container.


## Future

I use __sma2mqtt__ in 'production' and it works fine. Inverter values are currently read out via modbus, but I started reversing the [SMA inverter protocol](SMA%20Protocol.md) to get __sma2mqtt__ read values from all SMA products via UDP. SMA Speedwire protocol seems to be more stable and faster than Modbus, that's why I want to switch.

### Usage


```
USAGE: sma2mqtt <options>

OPTIONS:
  --log-level <log-level> Set the log level. (default: notice)
  --json                  send json output to stdout
  --mqtt-servername <mqtt-servername>
                          MQTT Server hostname (default: mqtt)
  --mqtt-port <mqtt-port> MQTT Server port (default: 1883)
  --mqtt-username <mqtt-username>
                          MQTT Server username (default: mqtt)
  --mqtt-password <mqtt-password>
                          MQTT Server password
  -e, --emit-interval <emit-interval>
                          Interval to send updates to mqtt Server. (default: 1.0)
  -b, --basetopic <basetopic>
                          MQTT Server topic. (default: sma/)
  --bind-address <bind-address>
                          Multicast Binding Listening Interface Address. (default: 0.0.0.0)
  --bind-port <bind-port> Multicast Binding Listening Port number. (default: 9522)
  --mcast-address <mcast-address>
                          Multicast Group Address. (default: 239.12.255.254)
  --mcast-port <mcast-port>
                          Multicast Group Port number. (default: 9522)
  --inverter-password <inverter-password>
                          Inverter Password. (default: 0000)
  --interesting-paths-and-values <interesting-paths-and-values>
                          Array of path:interval values we are interested in (default: dc-side/dc-measurements/power:1, ac-side/grid-measurements/power:1, ac-side/measured-values/daily-yield:30, battery/state-of-charge:20, battery/battery/temperature:30,
                          battery/battery-charge/battery-charge:20)
  -h, --help              Show help information.

```

