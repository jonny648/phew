#!/bin/zsh
# Compiles the TypeScript helper (Engine/), runs its tests, and puts the result where the app picks it up:
# Phew/Brain/engine.js, which is committed, so building the app needs neither Node nor the compiler.
# Run after any change in Engine/src. The compiler is pinned in Engine/package-lock.json; install scripts are off.
set -euo pipefail
root=${0:A:h:h}
cd "$root/Engine"
npm ci --ignore-scripts --no-audit --no-fund >/dev/null
npm test
cp dist/engine.js "$root/Phew/Brain/engine.js"
echo "$root/Phew/Brain/engine.js"
