#!/bin/bash
# Tests del paquete en Linux, con la misma versión de Swift que el Xcode del CI (ver CLAUDE.md).
# Uso: ./test.sh [argumentos de swift test, p. ej. --filter LocalDate]
# Si la PWA está clonada en ~/git/gym-companion (o en $PWA_DIR), sus datos reales entran en un test
# de importación; si no, ese test se salta y lo dice.
set -euo pipefail
cd "$(dirname "$0")"
pwa="${PWA_DIR:-$HOME/git/gym-companion}/db.json"
pwa_args=()
if [ -f "$pwa" ]; then
    pwa_args=(-v "$pwa:/pwa/db.json:ro" -e PWA_DB_JSON=/pwa/db.json)
else
    echo "Sin $pwa: el test de importación con los datos reales se salta." >&2
fi
exec docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp ${pwa_args[@]+"${pwa_args[@]}"} \
    -v "$(cd ../.. && pwd)":/w -w /w/Packages/GymCore swift:6.3.3 swift test "$@"
