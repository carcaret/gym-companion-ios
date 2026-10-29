#!/bin/bash
# El principio de un job con simulador: apunta el checkout en la cronología y deja en segundo plano
# el servicio de los simuladores (tarda de segundos a más de 2 minutos en arrancar la primera vez)
# y la medida de la CPU (diagnostico/cpu.log), mientras se preparan la compilación y el proyecto.
set -euo pipefail

scripts/ci-timeline.sh mark "checkout"
nohup xcrun simctl list devices > /dev/null 2>&1 &
nohup scripts/ci-cpu.sh diagnostico/cpu.log > /dev/null 2>&1 &
