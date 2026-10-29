#!/bin/bash
# El simulador de un job del CI, arrancado en segundo plano mientras se compila.
#
# Un simulador recién creado pasa 5-10 minutos en su primer arranque en "Waiting on Data
# Migration" (los migradores de iOS; el de localización, sobre todo). Por eso, la primera vez,
# en cuanto acaba de migrar, se apaga y se copia a ~/sim-cache, que el workflow guarda en la caché
# de Actions; en los runs siguientes se registra esa copia ya migrada y arranca en segundos. La
# copia se hace antes de instalar la app: no lleva datos de ningún test.
#
#   ci-simulator.sh pick <iphone|watch>
#       elige el tipo de aparato y el runtime y deja en $GITHUB_OUTPUT devtype, runtime y key (la
#       clave de la caché: cambia con el runtime y con Xcode)
#   ci-simulator.sh start <tipo de aparato> <runtime>
#       registra el de la caché (si está) o crea uno nuevo, lo arranca en segundo plano y deja
#       SIM_UDID y SIM_CACHED (1 si venía de la caché) en $GITHUB_ENV
#   ci-simulator.sh wait
#       espera a que haya arrancado y enseña cómo ha ido
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cache="$HOME/sim-cache"
state="${RUNNER_TEMP:-/tmp}/sim"
devices="$HOME/Library/Developer/CoreSimulator/Devices"
mark() { "$here/ci-timeline.sh" mark "$1"; }

case "$1" in
    pick)
        json=$(xcrun simctl list devices available -j)
        mark "servicio de simuladores listo"
        case "$2" in
            iphone)
                device=$(jq -c '[.devices | to_entries[] | select(.key | contains("iOS")) | .key as $rt
                                 | .value[] | select(.name | startswith("iPhone")) | . + {runtime: $rt}][0]' <<< "$json")
                ;;
            watch)
                # El reloj del usuario: Apple Watch Series 10 de 46 mm o, si no está, otro de 46 mm
                # (el Series 11 de 46 mm, que tiene la misma pantalla).
                device=$(jq -c '[.devices | to_entries[] | select(.key | contains("watchOS")) | .key as $rt
                                 | .value[] | . + {runtime: $rt}]
                                | (map(select(.name | contains("Series 10 (46mm)"))) + map(select(.name | contains("46mm"))))[0]' <<< "$json")
                ;;
        esac
        devtype=$(jq -r .deviceTypeIdentifier <<< "$device")
        runtime=$(jq -r .runtime <<< "$device")
        build=$(xcrun simctl list runtimes -j | jq -r --arg r "$runtime" '.runtimes[] | select(.identifier == $r) | .buildversion')
        # La versión de Xcode, del fichero: `xcodebuild -version` tarda en arrancar la primera vez.
        xcode=$(/usr/libexec/PlistBuddy -c 'Print :ProductBuildVersion' "$(xcode-select -p)/../version.plist" 2> /dev/null \
                || xcodebuild -version | awk '/Build version/ { print $3 }')
        echo "Aparato: $(jq -r .name <<< "$device") · $runtime ($build) · Xcode $xcode"
        {
            echo "devtype=$devtype"
            echo "runtime=$runtime"
            echo "key=sim-$2-${devtype##*.}-$build-$xcode-v1"
        } >> "$GITHUB_OUTPUT"
        ;;

    start)
        devtype=$2 runtime=$3
        mkdir -p "$state"
        cached=0
        if [ -f "$cache/udid" ] && [ -d "$cache/device" ]; then
            udid=$(cat "$cache/udid")
            mv "$cache/device" "$devices/$udid"
            # CoreSimulator solo ve los aparatos que hay al arrancar el servicio.
            killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
            if xcrun simctl list devices -j \
                | jq -e --arg u "$udid" '[.devices[][] | select(.udid == $u)] | length == 1' > /dev/null; then
                cached=1
                mark "simulador de la caché registrado"
            else
                echo "::warning::El simulador de la caché ($udid) no aparece en simctl; se crea uno nuevo"
                rm -rf "${devices:?}/$udid"
            fi
        fi
        if [ "$cached" = 0 ]; then
            udid=$(xcrun simctl create gym-ci "$devtype" "$runtime")
            mark "simulador creado"
        fi
        echo "Simulador: $udid (de la caché: $cached)"
        echo "SIM_UDID=$udid" >> "$GITHUB_ENV"
        echo "SIM_CACHED=$cached" >> "$GITHUB_ENV"
        nohup "$0" boot "$udid" "$cached" > "$state/boot.log" 2>&1 &
        ;;

    boot)   # en segundo plano, desde start
        udid=$2 cached=$3
        mark "arranque del simulador"
        xcrun simctl boot "$udid"
        xcrun simctl bootstatus "$udid" -b
        if [ "$cached" = 0 ]; then
            mark "simulador migrado"
            xcrun simctl shutdown "$udid"
            rm -rf "$cache"
            mkdir -p "$cache"
            # -c: clon de APFS, no copia los datos. Si falla, no hay caché, pero los tests siguen.
            if cp -Rc "$devices/$udid" "$cache/device"; then
                echo "$udid" > "$cache/udid"
                du -sh "$cache"
                mark "simulador copiado para la caché"
            else
                echo "No se ha podido copiar el simulador para la caché"
                rm -rf "$cache"
            fi
            xcrun simctl boot "$udid"
            xcrun simctl bootstatus "$udid" -b
        fi
        touch "$state/ready"
        mark "simulador listo"
        ;;

    wait)
        for _ in $(seq 1 1500); do
            [ -f "$state/ready" ] && break
            # Si el arranque ha fallado, no hay que esperar al tope.
            pgrep -f "ci-simulator.sh boot" > /dev/null || break
            sleep 1
        done
        echo "--- arranque del simulador (final del log) ---"
        tail -n 25 "$state/boot.log" || true
        test -f "$state/ready"
        ;;

    *)
        echo "uso: $0 pick <iphone|watch> | start <tipo> <runtime> | wait" >&2
        exit 2
        ;;
esac
