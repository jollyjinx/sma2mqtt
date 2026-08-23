#!/usr/bin/env bash
set -euo pipefail

runtime="${CONTAINER_COMMAND:-docker}"
image="${SWIFT_TEST_IMAGE:-swift:6.3.2-noble}"
container_name="sma2mqtt-swift-tests-$$"

cleanup() {
  "${runtime}" rm --force "${container_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${runtime}" run \
  --detach \
  --name "${container_name}" \
  "${image}" \
  sleep infinity >/dev/null

"${runtime}" exec "${container_name}" mkdir -p /workspace
"${runtime}" cp "${PWD}/." "${container_name}:/workspace"

"${runtime}" exec \
  --workdir /workspace \
  "${container_name}" \
  swift test \
    --scratch-path /tmp/sma2mqtt-build \
    --jobs 1
