---
name: spm-local-sma2mqtt
description: Guidance for working on the local sma2mqtt Swift package. Use when changing the package manifest, SMADevice discovery/query flow, MQTT publishing, object metadata translation, or package tests.
---

# sma2mqtt

Use this skill when the task is inside the `sma2mqtt` Swift package.

## Package map

- `Package.swift`: SwiftPM manifest. Swift 6 mode and strict concurrency are enabled for all targets.
- `Sources/sma2mqtt/`: CLI entry point and process-level wiring.
- `Sources/sma2mqttLibrary/SMADevice.swift`: device bootstrap, HTTP login/bootstrap, UDP query loop, and publish flow.
- `Sources/sma2mqttLibrary/DataObjects/`: metadata translation, HTTP value decoding, and MQTT payload shaping.
- `Sources/sma2mqttLibrary/Tools/`: queueing, MQTT transport, timers, and UDP helpers.
- `Sources/sma2mqttLibrary/Resources/`: bundled SMA metadata and translations.
- `Tests/sma2mqttTests/`: Swift Testing coverage, including queue behavior, packet decoding, and optional integration tests.

## Working rules

- Preserve the split between HTTP bootstrap and UDP polling. If the device-specific HTTP interface reveals a better object ID for a shared logical path, prefer that ID without breaking the UDP fallback chain.
- Treat object-path collisions as normal. Multiple SMA object IDs can map to one logical path, so fixes should be per-device and path-aware rather than global hardcoding.
- Keep MQTT topic shape stable. Multi-value topics that have been observed as arrays should stay arrays on later single-value updates.
- Preserve strict concurrency. Fix actor-isolation and sendability issues directly instead of disabling checks.
- Verify package changes with `swift test`. Integration tests are opt-in and should stay gated behind the existing flags.
