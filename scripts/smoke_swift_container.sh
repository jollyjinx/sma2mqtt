#!/usr/bin/env bash
set -euo pipefail

image="${1:-sma2mqtt:development}"
runtime="${CONTAINER_COMMAND:-container}"
container_name="sma2mqtt-swift-smoke-$$"

cleanup() {
  "${runtime}" stop "${container_name}" >/dev/null 2>&1 || true
  "${runtime}" rm "${container_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${runtime}" run \
  --detach \
  --name "${container_name}" \
  "${image}" \
  sleep infinity >/dev/null

"${runtime}" exec "${container_name}" sh -c '
  set -eu
  command -v sma2mqtt >/dev/null
  test -x /opt/sma2mqtt/sma2mqtt
  test -d /opt/sma2mqtt/sma2mqtt_sma2mqttLibrary.resources
  find /opt/sma2mqtt/sma2mqtt_sma2mqttLibrary.resources -type f | grep -q .
'

help_output="$("${runtime}" exec "${container_name}" sma2mqtt --help)"
grep -Fq 'USAGE: sma2mqtt' <<<"${help_output}"
grep -Fq -- '--mqtt-servername' <<<"${help_output}"
grep -Fq -- '--mcast-address' <<<"${help_output}"

echo "Container smoke passed: ${image}"
