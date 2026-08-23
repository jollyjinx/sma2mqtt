#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Build and push the sma2mqtt image.

Usage:
  ./scripts/build_and_push_image.sh (--gitmaster | --github) [options]

Registry (required):
  --gitmaster       Push gitmaster.jinx.eu/jnxpublic/sma2mqtt
  --github          Push ghcr.io/jollyjinx/sma2mqtt

Architecture:
  --arm64           Build only linux/arm64
  --amd64           Build only linux/amd64
                    With neither flag, build both architectures.

Image:
  --tag TAG         Image tag; defaults to the normalized current branch

Other:
  -h, --help        Show this help

On macOS the script uses Apple Container. On other hosts it uses Docker Buildx.
Registry login is an operator prerequisite.
EOF
}

fail() {
  echo "error: $*" >&2
  echo "Run '$0 --help' for usage." >&2
  exit 2
}

registry=""
architecture="both"
tag=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --gitmaster|--github)
      [ -z "${registry}" ] || fail "choose exactly one registry"
      registry="${1#--}"
      ;;
    --arm64|--amd64)
      [ "${architecture}" = "both" ] || fail "choose at most one architecture"
      architecture="${1#--}"
      ;;
    --tag)
      shift
      [ "$#" -gt 0 ] || fail "--tag requires a value"
      [ -z "${tag}" ] || fail "--tag may be supplied only once"
      tag="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option '$1'"
      ;;
  esac
  shift
done

[ -n "${registry}" ] || fail "one of --gitmaster or --github is required"

cd "${REPO_ROOT}"

if [ -z "${tag}" ]; then
  branch="$(git branch --show-current)"
  [ -n "${branch}" ] || fail "HEAD is detached; supply --tag"
  tag="$("${SCRIPT_DIR}/container_tag_for_branch.sh" "${branch}")"
fi

case "${tag}" in
  ''|*[!a-zA-Z0-9_.-]*|[.-]*) fail "invalid container tag '${tag}'" ;;
esac
[ "${#tag}" -le 128 ] || fail "container tag exceeds 128 characters"

case "${registry}" in
  gitmaster) image="gitmaster.jinx.eu/jnxpublic/sma2mqtt" ;;
  github) image="ghcr.io/jollyjinx/sma2mqtt" ;;
esac

case "${architecture}" in
  arm64) platforms=("linux/arm64") ;;
  amd64) platforms=("linux/amd64") ;;
  both) platforms=("linux/amd64" "linux/arm64") ;;
esac

image_ref="${image}:${tag}"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "warning: building from a dirty working tree" >&2
fi

echo "Image: ${image_ref}"
echo "Platforms: ${platforms[*]}"

if [ "$(uname -s)" = "Darwin" ]; then
  command -v container >/dev/null 2>&1 || fail "Apple Container is not installed"
  platform_arguments=()
  for platform in "${platforms[@]}"; do
    platform_arguments+=(--platform "${platform}")
  done
  container build \
    "${platform_arguments[@]}" \
    --file sma2mqtt.product.dockerfile \
    --tag "${image_ref}" \
    .
  container image push "${image_ref}"
else
  command -v docker >/dev/null 2>&1 || fail "Docker is not installed"
  docker buildx version >/dev/null 2>&1 || fail "Docker Buildx is not available"
  platform_list="$(IFS=,; echo "${platforms[*]}")"
  docker buildx build \
    --file sma2mqtt.product.dockerfile \
    --platform "${platform_list}" \
    --tag "${image_ref}" \
    --push \
    .
fi

echo "Published ${image_ref} (${platforms[*]})"
