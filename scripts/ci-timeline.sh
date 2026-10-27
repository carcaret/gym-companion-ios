#!/bin/bash
# Cronología de un job del CI: apunta cuándo pasa cada cosa (también lo que corre en segundo
# plano, como el arranque del simulador, que no tiene paso propio) y al final la escribe como
# tabla en el resumen del run.
#
#   ci-timeline.sh mark <qué>       apunta la hora
#   ci-timeline.sh summary <título> escribe la tabla en $GITHUB_STEP_SUMMARY
set -euo pipefail

file="${RUNNER_TEMP:-/tmp}/timeline.tsv"

case "$1" in
    mark)
        printf '%s\t%s\n' "$(date +%s)" "$2" >> "$file"
        echo "[cronología] $(date +%T) $2"
        ;;
    summary)
        [ -f "$file" ] || exit 0
        {
            echo "### $2"
            echo
            echo "| Desde el inicio | Desde lo anterior | Qué |"
            echo "|---:|---:|---|"
            sort -n -s -k1,1 "$file" | awk -F'\t' '
                function fmt(s) { return sprintf("%d min %02d s", int(s / 60), s % 60) }
                NR == 1 { start = $1; prev = $1 }
                { printf "| %s | %s | %s |\n", fmt($1 - start), fmt($1 - prev), $2; prev = $1 }'
            echo
        } >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
        ;;
    *)
        echo "uso: $0 mark <qué> | summary <título>" >&2
        exit 2
        ;;
esac
