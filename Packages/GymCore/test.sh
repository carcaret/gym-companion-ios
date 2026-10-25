#!/bin/sh
# Tests del paquete en Linux, con la misma versión de Swift que el Xcode del CI (ver CLAUDE.md).
# Uso: ./test.sh [argumentos de swift test, p. ej. --filter LocalDate]
# Si la PWA está clonada al lado (~/git/gym-companion), sus datos reales entran en un test de importación.
cd "$(dirname "$0")" || exit 1
pwa="$(cd ../../.. && pwd)/gym-companion/db.json"
[ -f "$pwa" ] && pwa_args="-v $pwa:/pwa/db.json:ro -e PWA_DB_JSON=/pwa/db.json"
# shellcheck disable=SC2086
exec docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp $pwa_args \
  -v "$(cd ../.. && pwd)":/w -w /w/Packages/GymCore swift:6.3.3 swift test "$@"
