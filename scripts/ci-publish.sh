#!/bin/bash
# Publica GymCompanion.ipa (del job release-build) como la release "latest", que el NAS
# (ios-signer) firma e instala en el iPhone.
set -euo pipefail

gh release delete latest --yes --cleanup-tag 2>/dev/null || true
gh release create latest GymCompanion.ipa GymCompanion.ipa.sha256 \
    --title "Build $GITHUB_RUN_NUMBER" \
    --notes "Commit $GITHUB_SHA" \
    --target "$GITHUB_SHA"
