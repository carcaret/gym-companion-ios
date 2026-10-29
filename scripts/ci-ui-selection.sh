#!/bin/bash
# Las clases de tests de UI de una parte del job `app`, como argumentos de xcodebuild, uno por
# línea: la 1 corre las de $PART_1, la 2 las de $PART_2 y la 3 todas las demás (así una clase
# nueva nunca se queda sin correr). Para la rama de prueba de un test, aquí va el `-only-testing`.
#
#   ci-ui-selection.sh <1|2|3>
set -euo pipefail

# Sin clases en una parte, la 1 o la 2 correrían todos los tests: mejor fallar.
[ -n "${PART_1:-}" ] && [ -n "${PART_2:-}" ] || { echo "PART_1 y PART_2 no pueden estar vacías" >&2; exit 1; }

case "$1" in
    1) for class in $PART_1; do echo "-only-testing:GymCompanionUITests/$class"; done ;;
    2) for class in $PART_2; do echo "-only-testing:GymCompanionUITests/$class"; done ;;
    3) for class in $PART_1 $PART_2; do echo "-skip-testing:GymCompanionUITests/$class"; done ;;
    *) echo "uso: $0 <1|2|3>" >&2; exit 2 ;;
esac
