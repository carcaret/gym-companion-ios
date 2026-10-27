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
#
# Las carpetas, con la fecha de su fichero más reciente: un catálogo de imágenes (.xcassets) es una
# carpeta, y con la hora del checkout Xcode lo recompilaba en cada run (de 1 a 3 minutos).
#
# Los commits de merge, con lo que cambian respecto a su primer padre: sin eso `git log` no da sus
# ficheros, y lo que se cambia al resolver un conflicto se quedaba con la fecha del commit anterior
# y no se recompilaba (2026-10-27). En una PR, el checkout es el merge de la rama con master, y lo
# de la rama sale con la fecha de ese merge.
set -euo pipefail

git -c core.quotepath=off log --diff-merges=first-parent --format='%x01%ct' --name-only | perl -ne '
    chomp;
    if (/^\x01(\d+)$/) { $time = $1; next }
    next if $_ eq "" || $seen{$_}++;
    next unless -e $_;
    utime $time, $time, $_;
    for (my $dir = $_; $dir =~ s{/[^/]*$}{}; ) { $dirs{$dir} = $time if ($dirs{$dir} // 0) < $time }
    END { utime $dirs{$_}, $dirs{$_}, $_ for sort { length($b) <=> length($a) } keys %dirs }
'
