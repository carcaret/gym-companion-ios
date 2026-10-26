#!/bin/bash
# ¿Hace falta volver a pasar los tests? En master no, si el commit es una PR fusionada cuyo
# último commit tiene exactamente el mismo árbol (los mismos ficheros, byte a byte) y su run de
# este workflow terminó bien: el código ya está probado. Así lo fusionado llega al iPhone en
# lo que tarda compilar la release, no en otro CI entero.
#
# Cualquier otra cosa (una PR, un push directo a master, una PR fusionada sin estar al día con
# master, o cuyo run falló) pasa todos los tests. Deja tested=true|false en $GITHUB_OUTPUT y el
# motivo en el resumen del run.
set -euo pipefail

repo=$GITHUB_REPOSITORY
sha=$GITHUB_SHA

decide() {
    echo "tested=$1" >> "$GITHUB_OUTPUT"
    echo "$2"
    echo "**Tests**: $2" >> "$GITHUB_STEP_SUMMARY"
    exit 0
}

[ "$GITHUB_EVENT_NAME" = push ] || decide false "se pasan todos (es una PR)."

pr=$(gh api "repos/$repo/commits/$sha/pulls" --jq '[.[] | select(.merged_at != null)][0] | "\(.number) \(.head.sha)"' || true)
[ -n "$pr" ] && [ "$pr" != "null null" ] || decide false "se pasan todos (push a master que no viene de una PR)."
read -r number head <<< "$pr"

tree=$(gh api "repos/$repo/git/commits/$sha" --jq .tree.sha)
head_tree=$(gh api "repos/$repo/git/commits/$head" --jq .tree.sha)
[ "$tree" = "$head_tree" ] \
    || decide false "se pasan todos (la PR #$number no estaba al día con master: el árbol fusionado no es el probado)."

passed=$(gh api "repos/$repo/actions/workflows/build.yml/runs?head_sha=$head&event=pull_request&status=success" --jq .total_count)
[ "$passed" -gt 0 ] || decide false "se pasan todos (el run de la PR #$number para ${head:0:7} no terminó bien)."

decide true "ya pasaron en la PR #$number (${head:0:7}, mismo árbol que este commit): solo se compila y se publica."
