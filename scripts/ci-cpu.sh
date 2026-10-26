#!/bin/bash
# Apunta cada 2 s la CPU de la app y del simulador mientras corren los tests (diagnostico/cpu.log).
# Sirve para ver si la app se queda dibujando sin parar: XCTest espera a que deje de animar antes
# de cada toque, y una animación que no acaba le cuesta 60 s de espera.
#
#   ci-cpu.sh <fichero>   (en segundo plano; para al acabar el job)
set -uo pipefail

while true; do
    ps -A -o %cpu=,comm= | awk -v t="$(date +%T)" '
        /GymCompanion\.app\/GymCompanion$/ { app += $1 }
        /GymCompanionUITests-Runner/ { runner += $1 }
        { total += $1 }
        END { printf "%s app %5.1f runner %5.1f total %6.1f\n", t, app, runner, total }'
    sleep 2
done >> "$1"
