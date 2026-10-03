#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: build_openrv.sh [-n] [-o DIRECTORY] [--extract-only] [-h]

Build OpenRV and export its archive, source metadata, and SHA-256 checksum.
  -n              Disable Docker layer cache (expensive).
  -o DIRECTORY    Output directory (default: ./out in the repository).
  --extract-only  Export from an existing image without rebuilding.
  -h, --help      Show this help.

Environment:
  IMAGE_NAME      Docker image tag (default: openrv_rocky9).
  OPENRV_REF      Upstream tag/branch to build (default: v4.0.2).
                  Other releases may require dependency changes.
  BUILDKIT_PROGRESS  Docker progress format (default: plain).
HELP
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUTPUT_DIR="$SCRIPT_DIR/out"
IMAGE_NAME=${IMAGE_NAME:-openrv_rocky9}
OPENRV_REF=${OPENRV_REF:-v4.0.2}
NO_CACHE=false
EXTRACT_ONLY=false
while (($#)); do
  case "$1" in
    -n) NO_CACHE=true; shift ;;
    -o)
      [[ $# -ge 2 && -n "$2" ]] || { echo 'Missing output directory after -o' >&2; exit 2; }
      OUTPUT_DIR=$2; shift 2 ;;
    --extract-only) EXTRACT_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
if [[ "$EXTRACT_ONLY" == true && "$NO_CACHE" == true ]]; then
  echo '-n cannot be combined with --extract-only' >&2
  exit 2
fi
for tool in docker tar sha256sum; do
  command -v "$tool" >/dev/null || { echo "Required command not found: $tool" >&2; exit 1; }
done
docker info >/dev/null
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR=$(cd -- "$OUTPUT_DIR" && pwd)

if [[ "$EXTRACT_ONLY" != true ]]; then
  BUILD_ARGS=(--load -t "$IMAGE_NAME" --build-arg "OPENRV_REF=$OPENRV_REF")
  [[ "$NO_CACHE" != true ]] || BUILD_ARGS+=(--no-cache)
  echo "Building $IMAGE_NAME from OpenRV $OPENRV_REF..."
  BUILDKIT_PROGRESS=${BUILDKIT_PROGRESS:-plain} docker build "${BUILD_ARGS[@]}" "$SCRIPT_DIR"
fi

# An anonymous, stopped container is enough for docker cp. Never remove a
# container belonging to another build, and clean up on failure or interruption.
CONTAINER_ID=''
TEMP_DIR=$(mktemp -d "$OUTPUT_DIR/.openrv-export.XXXXXX")
cleanup() {
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm "$CONTAINER_ID" >/dev/null || true
  fi
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
CONTAINER_ID=$(docker create "$IMAGE_NAME" /bin/true)
docker cp "$CONTAINER_ID:/home/rv/OpenRV/build_name.txt" "$TEMP_DIR/build_name.txt"
BUILD_NAME=$(cat "$TEMP_DIR/build_name.txt")
[[ "$BUILD_NAME" =~ ^OpenRV-[A-Za-z0-9._-]+$ ]] || { echo 'Invalid build name in image' >&2; exit 1; }
docker cp "$CONTAINER_ID:/home/rv/openrv-source-commit.txt" "$TEMP_DIR/source-commit.txt"
SOURCE_COMMIT=$(cat "$TEMP_DIR/source-commit.txt")
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid source commit in image' >&2; exit 1; }
# Use the actual image's source revision, including when --extract-only is used.
ARTIFACT_NAME="${BUILD_NAME}-${SOURCE_COMMIT:0:12}.tar.gz"
for name in "$ARTIFACT_NAME" "$ARTIFACT_NAME.sha256" "$ARTIFACT_NAME.build-info.txt"; do
  [[ ! -e "$OUTPUT_DIR/$name" ]] || { echo "Output already exists: $OUTPUT_DIR/$name (use another -o directory)" >&2; exit 1; }
done
docker cp "$CONTAINER_ID:/home/rv/OpenRV/${BUILD_NAME}.tar.gz" "$TEMP_DIR/$ARTIFACT_NAME"
# Read the entire archive, checking compression and tar structure before publishing.
tar -tzf "$TEMP_DIR/$ARTIFACT_NAME" > /dev/null
IMAGE_ID=$(docker inspect --format '{{.Image}}' "$CONTAINER_ID")
printf 'source_commit=%s\nimage_id=%s\narchive_root=%s\n' "$SOURCE_COMMIT" "$IMAGE_ID" "$BUILD_NAME" > "$TEMP_DIR/$ARTIFACT_NAME.build-info.txt"
(cd "$TEMP_DIR" && sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256")
for name in "$ARTIFACT_NAME" "$ARTIFACT_NAME.sha256" "$ARTIFACT_NAME.build-info.txt"; do
  mv -- "$TEMP_DIR/$name" "$OUTPUT_DIR/$name"
done
echo "Build exported: $OUTPUT_DIR/$ARTIFACT_NAME"
