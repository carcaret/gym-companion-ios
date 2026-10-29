#!/bin/bash
# Apunta cada 2 s la CPU de la app, la del runner de los tests, la de toda la máquina (sobre 100 %
# por núcleo) y los cinco procesos que más gastan, desde el inicio del job (diagnostico/cpu.log).
# Sirve para ver quién se come la máquina: con la app casi parada iba al 220 % de 300, y XCTest
# espera a que la app deje de animar antes de cada toque.
#
#   ci-cpu.sh <fichero>   (en segundo plano; para al acabar el job)
# Sin `-e`: el bucle no tiene que pararse porque falle una medida (un proceso que ya no existe).
set -uo pipefail

mkdir -p "$(dirname "$1")"
while true; do
    ps -A -o %cpu=,comm= | sort -rn | awk -v t="$(date +%T)" '
        { name = $0; sub(/^ *[0-9.]+ +/, "", name); sub(/.*\//, "", name) }
        name == "GymCompanion" { app += $1 }
        name == "GymCompanionUITests-Runner" { runner += $1 }
        { total += $1 }
        NR <= 5 { top = top sprintf(" %s:%.0f", name, $1) }
        END { printf "%s app %5.1f runner %5.1f total %6.1f |%s\n", t, app, runner, total, top }'
    sleep 2
done >> "$1"
