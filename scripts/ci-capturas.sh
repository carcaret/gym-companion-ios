#!/bin/bash
# Saca las capturas de los .xcresult a <carpeta>, una por PNG con el nombre de la captura.
#
#   ci-capturas.sh <carpeta> <.xcresult>...
set -euo pipefail

out=$1
shift
mkdir -p "$out"
for result in "$@"; do
    [ -d "$result" ] || continue
    tmp=$(mktemp -d)
    xcrun xcresulttool export attachments --path "$result" --output-path "$tmp"
    jq -r '.[].attachments[] | [.exportedFileName, .suggestedHumanReadableName] | @tsv' "$tmp/manifest.json" \
        | while IFS=$'\t' read -r file name; do
              # upload-artifact no admite " : < > | * ? en los nombres (salen en las descripciones de un fallo).
              name=$(printf '%s' "${name%%_*}" | tr -d '":<>|*?')
              cp "$tmp/$file" "$out/$name.png"
          done
    rm -rf "$tmp"
done
ls "$out"
