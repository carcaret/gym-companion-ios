#!/bin/bash
# Pone a cada fichero versionado la fecha de su último commit (solo macOS: `date -r`).
#
# El checkout deja todos los ficheros con la hora actual, y Xcode y SwiftPM recompilan lo que
# tiene otra fecha que en la compilación guardada en la caché. Con la fecha del commit, un
# fichero sin cambios conserva la de entonces y solo se recompila lo que ha cambiado. Necesita
# el historial entero (`fetch-depth: 0`).
set -euo pipefail

git ls-files -z | while IFS= read -r -d '' file; do
    seconds=$(git log -1 --format=%ct -- "$file")
    touch -t "$(date -r "$seconds" +%Y%m%d%H%M.%S)" "$file"
done
