#!/bin/bash
# xcodebuild con la hora delante de cada línea, el log entero en diagnostico/ y solo el final en
# la salida del paso; al acabar, apunta la marca en la cronología y, si falló, enseña los errores.
# Sale con el código de xcodebuild.
#
#   ci-xcodebuild.sh <log> <líneas> <marca> <argumentos de xcodebuild…>
set -euo pipefail

log="diagnostico/$1"
lines="$2"
mark="$3"
shift 3

mkdir -p diagnostico
set +e
xcodebuild "$@" 2>&1 | perl -MPOSIX -pe 'BEGIN { $| = 1 } print strftime("%H:%M:%S ", localtime)' \
    | tee "$log" | tail -n "$lines"
status=${PIPESTATUS[0]}
set -e
scripts/ci-timeline.sh mark "$mark"
if [ "$status" -ne 0 ]; then
    grep -E ': error:' "$log" | sort -u | head -n 30 || true
fi
exit "$status"
