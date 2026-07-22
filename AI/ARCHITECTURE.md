---
title: sma2mqtt architecture
summary: Process flow, target ownership, device bootstrap, polling, and publication boundaries.
applies_to: Package.swift and Sources
last_verified: 2026-07-22
---

# Architecture

sma2mqtt is a Swift 6 service split into a thin executable target and a reusable library target. Strict concurrency is enabled for every target.

## Target map

| Target/path | Responsibility |
| --- | --- |
| `Sources/sma2mqtt/sma2mqtt.swift` | Argument parsing, password precedence, logger setup, signal lifecycle, collaborator construction, and receive loop |
| `SMALighthouse` | Multicast socket ownership, discovery loop, address normalization, device cache, and packet routing |
| `SMADevice` | Per-device HTTP bootstrap, metadata selection, UDP session/polling, decoding, and MQTT path publication |
| `DataObjects/` | Device metadata, translations, HTTP value decoding, scaling, and stable payload shapes |
| `SMAPacket/` and `Obis/` | SMA tag/net packet and Sunny Home Manager OBIS parsing/generation |
| `Tools/` | MQTT delivery/gating, UDP/multicast helpers, HTTP client ownership, timers, and query queues |
| `Resources/` | Bundled object metadata, translations, OBIS definitions, and packet definitions |
| `Tests/sma2mqttTests/` | Swift Testing unit/fixture coverage plus gated live-device tests |

## Runtime flow

```text
sma2mqtt command
    -> MQTTPublisher
    -> SMALighthouse
        -> multicast receive + periodic discovery
        -> per-address SMADevice actor
            -> HTTPS, then HTTP bootstrap
            -> device metadata/translations or bundled fallback
            -> Sunny Home Manager OBIS multicast path
            -> inverter UDP login/query path
            -> normalized PublishedValue
                -> MQTTPublicationGate
                -> MQTT + optional JSON stdout mirror
```

## Device cache

`SMALighthouse` keeps address entries in `inProgress`, `ready`, or `failed` states. Concurrent packets for a new address share the in-progress initialization task. Failed addresses are ignored for 30 seconds before retry. Devices are evicted when their actor reports that recent receive/request activity no longer satisfies its validity window.

## Bootstrap and fallback

`SMADevice` probes HTTPS and falls back to HTTP. Sunny Home Manager is recognized through its legal-notices response and then consumes OBIS multicast values. Other devices attempt to load object metadata and English translations from their web interface, seed a UDP query queue, perform an HTTP login, learn the device name, and inspect current values.

If device metadata or HTTP bootstrap fails, bundled resources and UDP discovery remain available. Preserve this separation: HTTP observations may improve the object ID chosen for one device/path, but must not remove the fallback chain used by other devices.

## Query ownership

`QueryQueue` stores one active object ID per logical path plus fallback IDs. Successful HTTP observations can promote the device-specific ID immediately. A failed active UDP request promotes the next fallback where available; repeated failures eventually remove an invalid query.

## Concurrency contract

Long-lived mutable components are actors (`SMALighthouse`, `SMADevice`, `MQTTPublisher`, socket helpers). The executable retains `DispatchSourceSignal` instances on the Main Actor. Keep blocking/network work out of actor-critical sections where possible, preserve cancellation of discovery/refresh tasks, and resolve strict-concurrency diagnostics rather than weakening compiler settings.

## Resource contract

The library loads its JSON files through `Bundle.module`. Container builds must copy `sma2mqtt_sma2mqttLibrary.resources` beside the executable. Resource names and output paths are runtime contracts; validate a release/container artifact whenever they change.
