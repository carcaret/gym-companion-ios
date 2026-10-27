#!/bin/bash
# Lo que ha tardado cada test de un .xcresult, del más lento al más rápido, en el resumen del run.
# Deja también el JSON entero de xcresulttool en <carpeta>, para mirarlo si la tabla no basta.
#
#   ci-test-times.sh <.xcresult> <título> <carpeta>
set -euo pipefail

result=$1 title=$2 out=$3
[ -d "$result" ] || exit 0
mkdir -p "$out"
name=$(basename "$result" .xcresult)
xcrun xcresulttool get test-results summary --path "$result" > "$out/$name-summary.json" || true
xcrun xcresulttool get test-results tests --path "$result" > "$out/$name-tests.json"

{
    echo "### $title"
    echo
    jq -r '"Inicio \(.startTime // "?" | tostring) · fin \(.finishTime // "?" | tostring) · \(.passedTests // "?") bien, \(.failedTests // "?") mal, \(.skippedTests // "?") saltados"' \
        "$out/$name-summary.json" 2>/dev/null || true
    echo
    echo "| Tiempo | Resultado | Test |"
    echo "|---:|---|---|"
    jq -r '.. | objects | select(.nodeType? == "Test Case")
           | [(.durationInSeconds // (.duration // "" | rtrimstr("s") | tonumber? ) // 0), .result, (.nodeIdentifier // .name)]
           | @tsv' "$out/$name-tests.json" \
        | sort -t$'\t' -k1,1 -g -r \
        | awk -F'\t' '{ total += $1; printf "| %.1f s | %s | %s |\n", $1, $2, $3 } END { printf "| **%.0f s** | | **total** |\n", total }'
    echo
    # Los que han fallado y se han repetido (-retry-tests-on-failure): pasan, pero hay que mirarlos.
    retried=$(jq -r '.. | objects | select(.nodeType? == "Test Case")
                     | select([.children[]? | select(.nodeType == "Repetition")] | length > 1)
                     | "- \(.nodeIdentifier // .name): " + ([.children[] | select(.nodeType == "Repetition") | .result] | join(" → "))' \
        "$out/$name-tests.json")
    if [ -n "$retried" ]; then
        echo "**Repetidos** (fallaron y se repitieron; el vídeo del fallo está en el .xcresult):"
        echo
        echo "$retried"
        echo
    fi
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
