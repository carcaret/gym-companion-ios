#!/bin/sh
# Tests del paquete en Linux, con la misma versión de Swift que el Xcode del CI (ver CLAUDE.md).
# Uso: ./test.sh [argumentos de swift test, p. ej. --filter LocalDate]
cd "$(dirname "$0")" && exec docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$(cd ../.. && pwd)":/w -w /w/Packages/GymCore swift:6.3.3 swift test "$@"
