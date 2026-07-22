---
title: sma2mqtt operations and validation
summary: Network, MQTT, signals, secrets, container publishing, and test boundaries.
applies_to: Runtime configuration, tests, Dockerfile, and deployment scripts
last_verified: 2026-07-22
---

# Operations and validation

## Network model

The process needs simultaneous access to:

- the SMA multicast group, default `239.12.255.254:9522`;
- device HTTP/HTTPS endpoints for bootstrap where available;
- device UDP endpoints for inverter queries;
- the configured MQTT broker.

Multicast normally stays inside one LAN/VLAN. Validate interface selection and container network mode on the deployment host. Port publishing alone does not guarantee multicast membership or delivery.

## Configuration invariants

- Release defaults are `notice` logging and base topic `sma/`; debug defaults are `debug` and `example/sma/`.
- The inverter password priority is CLI, environment, then `0000`.
- `--mqtt-unchanged-publish-interval` must be finite and non-negative.
- Interesting paths use `path:seconds`. Malformed entries are currently discarded during parsing; duplicate keys are not a supported configuration.
- `--json-output` is an additional stdout sink, not an MQTT-offline mode.
- `SIGUSR1` cycles `debug -> trace -> info -> debug`; any other starting level moves to `debug`.
- Signal sources must remain retained for the process lifetime.

## Known option gaps

Two exposed options are not wired through in the current development revision:

1. `MQTTPublisher.init` ignores its password parameter and always passes an empty password to MQTTNIO.
2. `SMALighthouse.init` ignores its bind-port parameter and configures the receiver with the multicast port.

Treat password-authenticated MQTT and an independently selected local bind port as unsupported until implementation and tests prove otherwise. Keep this warning synchronized with code changes.

## MQTT stability

MQTT topic shape and JSON type are downstream contracts:

- normalize one trailing base-topic slash before joining paths;
- preserve logical path names unless a migration is intentional;
- keep topics that have emitted arrays as arrays on subsequent single-value updates, including across normalized device-name keys;
- suppress unchanged retained publications;
- reset publication history on broker disconnect so state is republished after reconnect;
- do not confuse publication throttling with SMA polling frequency.

## Validation layers

Run the deterministic suite first:

```sh
swift package dump-package
swift build
swift test
swift build -c release --product sma2mqtt
```

On 2026-07-22 with Apple Swift 6.4, these checks passed. The default test run executed 36 tests in six suites and skipped three gated tests: two live-device tests and one missing pcap fixture.

Optional fixture validation:

```sh
swift test -- --pcap-file /absolute/path/to/capture.pcap
```

Optional live-device validation:

```sh
SMA_INTEGRATION_TESTS=1 swift test
```

The current live tests contain local/default device addresses. Inspect them and ensure the target network is correct before opting in. Never commit real inverter or broker passwords.

For runtime changes, also verify multicast discovery, HTTP-to-UDP fallback, broker reconnect, retained and non-retained topics, JSON stdout framing, and both signals in a controlled environment.

## Container validation

The product Dockerfile uses matching Swift 6.3 builder/runtime images, resolves dependencies in a cacheable layer, dynamically finds the release binary/resource bundle, and copies both into a slim image.

```sh
docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
docker run --rm --network host --env INVERTER_PASSWORD sma2mqtt sma2mqtt --mqtt-servername 127.0.0.1
```

The image uses `CMD ["sma2mqtt"]`, not an entrypoint. Supplying arguments after the image replaces that default command, so repeat `sma2mqtt` before any options.

On 2026-07-22, a local-architecture Docker build and `sma2mqtt --help` container smoke test passed. Linux compilation emitted a deprecation warning for MQTTNIO's event-loop provider but completed and copied the resource bundle. A controlled run with reachable devices and broker is still required for network behavior.

The Dockerfile copies only `Package.swift` before resolution and does not copy `Package.resolved`. It therefore resolves the newest compatible dependency graph, which can differ substantially from a developer's local checkout. Treat dependency updates observed only inside Docker as deliberate inputs to validation, not as proof that the locked/local graph is equivalent.

## Publishing boundary

`.github/workflows/docker-publish.yml` publishes multi-architecture GHCR images from GitHub branch/tag events. `ghcrupload.sh` is a manual publisher that reads a token from the macOS Keychain and mutates GHCR. `build.sh` is a legacy deployment-specific Docker launcher.

Do not run publishing scripts as validation. Before publishing, verify the intended registry, tag, architectures, credentials, and whether the source commit exists on the server that triggers the workflow.

## Reference repositories

`Temp/` contains separate reverse-engineering/reference repositories. They are not root project source and may intentionally be partial or dirty. Never stage, repair, clean, or commit them as part of sma2mqtt work.
