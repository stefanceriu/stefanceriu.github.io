#!/bin/bash
# Builds the wasm module and lays the site out in dist/.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
SDK="${SWIFT_SDK_ID:-swift-6.3.3-RELEASE_wasm}"

swift package --swift-sdk "$SDK" js --use-cdn -c "$CONFIG"

rm -rf dist
mkdir -p dist
cp Web/* dist/
cp -R ".build/plugins/PackageToJS/outputs/Package" dist/Package

echo "dist/ ready — serve it with: python3 -m http.server -d dist 8000"
