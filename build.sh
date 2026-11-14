#!/bin/sh
# Builds the RPMs in the Sailfish SDK Docker image, one build folder per architecture so a
# package never picks up another architecture's binary. Usage: ./build.sh [aarch64 armv7hl i486]
set -e
IMAGE=coderus/sailfishos-platform-sdk:5.1.0.11
TARGET=SailfishOS-5.1.0.11
ARCHS=${*:-aarch64 armv7hl}
SRC=$(cd "$(dirname "$0")" && pwd)
chmod -R a+rwX "$SRC"
mkdir -p "$SRC/RPMS"
for arch in $ARCHS; do
    rm -rf "$SRC/build-$arch"
    mkdir -p "$SRC/build-$arch"
    chmod a+rwX "$SRC/build-$arch"
    docker run --rm -v "$SRC":/home/mersdk/src -w /home/mersdk/src/build-$arch "$IMAGE" \
        bash -lc "mb2 -t $TARGET-$arch build /home/mersdk/src" > "$SRC/build-$arch/build.log" 2>&1 || {
            echo "Build failed for $arch, see build-$arch/build.log"; exit 1; }
    grep -E '\.(cpp|h):[0-9]+:' "$SRC/build-$arch/build.log" || true
    cp "$SRC"/build-$arch/RPMS/*.rpm "$SRC/RPMS/"
done
ls -la "$SRC/RPMS"
