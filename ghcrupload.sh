#!/bin/bash
#
# Builds the production container image and pushes it to GitHub Container Registry.
#
# Purpose:
# - build `sma2mqtt.product.dockerfile` for the local architecture by default
# - tag the image for GHCR
# - authenticate with a GitHub token stored in macOS Keychain
# - push the image to `ghcr.io`
# - use Docker only when `--all-arch` needs a joined multi-architecture image
#
# Typical use:
# - run `./ghcrupload.sh <tag>` to publish a specific image tag
# - run `./ghcrupload.sh --all-arch <tag>` to publish a joined `amd64` + `arm64` image
# - if no tag is provided, the script uses `jinx`
#
# Configuration:
# - `GHCR_USER` controls the GHCR login user
# - `IMAGE_REPO` controls the destination image repository
# - `KEYCHAIN_ITEM` is the Keychain entry that stores the GitHub token

set -euo pipefail

GHCR_USER="${GHCR_USER:-jollyjinx}"
IMAGE_REPO="${IMAGE_REPO:-ghcr.io/jollyjinx/sma2mqtt}"
KEYCHAIN_ITEM="${KEYCHAIN_ITEM:-github-token-sma2mqtt}"
IMAGE_TAG="jinx"
TAG_PROVIDED=false
ALL_ARCH=false

usage() {
  cat <<'EOF'
Usage: ./ghcrupload.sh [--all-arch] [tag]

Options:
  --all-arch   Build and push a combined linux/amd64 + linux/arm64 image.
  --help       Show this help text.

Defaults:
  tag          jinx
  platform     local machine architecture only
EOF
}

detect_local_platform() {
  case "$(uname -m)" in
    arm64|aarch64)
      echo "linux/arm64"
      ;;
    x86_64|amd64)
      echo "linux/amd64"
      ;;
    *)
      echo "unsupported local architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all-arch)
      ALL_ARCH=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ "$TAG_PROVIDED" = true ]; then
        echo "only one image tag may be provided" >&2
        usage >&2
        exit 1
      fi
      IMAGE_TAG="$1"
      TAG_PROVIDED=true
      shift
      ;;
  esac
done

IMAGE_REF="${IMAGE_REPO}:${IMAGE_TAG}"

if ! command -v security >/dev/null 2>&1; then
  echo "the macOS security command is required to read the GHCR token" >&2
  exit 1
fi

if ! GHCR_TOKEN="$(security find-generic-password -w -s "$KEYCHAIN_ITEM")" || [ -z "$GHCR_TOKEN" ]; then
  echo "no token found in keychain item '$KEYCHAIN_ITEM'" >&2
  exit 1
fi

if [ "$ALL_ARCH" = true ]; then
  PLATFORMS="linux/amd64,linux/arm64"

  if ! command -v docker >/dev/null 2>&1; then
    echo "docker buildx is required for --all-arch because container cannot publish a joined multi-architecture image" >&2
    exit 1
  fi

  printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

  docker buildx build \
    --file sma2mqtt.product.dockerfile \
    --platform "$PLATFORMS" \
    --tag "$IMAGE_REF" \
    --push \
    .
else
  PLATFORM="$(detect_local_platform)"

  if ! command -v container >/dev/null 2>&1; then
    echo "container is required for local-architecture GHCR pushes" >&2
    exit 1
  fi

  printf '%s' "$GHCR_TOKEN" | container registry login ghcr.io -u "$GHCR_USER" --password-stdin

  container build \
    --file sma2mqtt.product.dockerfile \
    --platform "$PLATFORM" \
    --tag "$IMAGE_REF" \
    .
  container image push --platform "$PLATFORM" "$IMAGE_REF"
fi

echo "pushed $IMAGE_REF for ${PLATFORMS:-$PLATFORM}"
