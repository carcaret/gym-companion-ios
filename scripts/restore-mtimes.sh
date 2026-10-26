#!/bin/bash
# Pone a cada fichero versionado la fecha de su último commit.
#
# El checkout deja todos los ficheros con la hora actual, y Xcode y SwiftPM recompilan lo que
# tiene otra fecha que en la compilación guardada en la caché. Con la fecha del commit, un
# fichero sin cambios conserva la de entonces y solo se recompila lo que ha cambiado. Necesita
# el historial entero (`fetch-depth: 0`).
#
# Una sola pasada por el historial, del commit más nuevo al más viejo: la primera vez que sale un
# fichero es su último commit. (Un `git log` por fichero tardaba más de un minuto en el CI, con el
# simulador arrancando a la vez.)
set -euo pipefail

git -c core.quotepath=off log --format='%x01%ct' --name-only | perl -ne '
    chomp;
    if (/^\x01(\d+)$/) { $time = $1; next }
    next if $_ eq "" || $seen{$_}++;
    utime $time, $time, $_ if -e $_;
'
