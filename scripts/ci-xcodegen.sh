#!/bin/bash
# Genera el proyecto con XcodeGen, descargado de su release y comprobado con su SHA-256.
# (`brew install xcodegen` pasaba unos 50 s arrancando antes de descargar nada.) Para cambiar de
# versión: la nueva y el `shasum -a 256` de su xcodegen.zip.
set -euo pipefail

version=2.46.0
sha256=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806

dir="${RUNNER_TEMP:-/tmp}/xcodegen-$version"
if [ ! -x "$dir/xcodegen/bin/xcodegen" ]; then
    mkdir -p "$dir"
    curl -fsSLo "$dir/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/$version/xcodegen.zip"
    echo "$sha256  $dir/xcodegen.zip" | shasum -a 256 -c -
    unzip -q "$dir/xcodegen.zip" -d "$dir"
fi
"$dir/xcodegen/bin/xcodegen" generate
