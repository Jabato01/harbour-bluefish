#!/bin/sh
# Runs the C++ unit tests and the QML compile check in the SDK image (i486 target, no screen).
set -e
IMAGE=coderus/sailfishos-platform-sdk:5.1.0.11
T=SailfishOS-5.1.0.11-i486
SRC=$(cd "$(dirname "$0")/.." && pwd)
chmod -R a+rwX "$SRC"
docker run --rm -v "$SRC":/home/mersdk/src -w /home/mersdk/src/tests "$IMAGE" bash -lc "
    set -e
    mkdir -p build-unit build-qmlcheck /tmp/rt
    (cd build-unit && sb2 -t $T qmake ../tests.pro >/dev/null && sb2 -t $T make -s >/dev/null && sb2 -t $T ./tst_bsky)
    (cd build-qmlcheck && sb2 -t $T qmake ../qmlcheck/qmlcheck.pro >/dev/null && sb2 -t $T make -s >/dev/null \
        && XDG_RUNTIME_DIR=/tmp/rt QT_QPA_PLATFORM=minimal sb2 -t $T ./qmlcheck /home/mersdk/src/qml)
" 2>&1 | grep -v 'bus connection'
