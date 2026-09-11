#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/core/fightcore"
export PATH="${HOME}/.cargo/bin:${PATH}"

rustup target add wasm32-unknown-unknown >/dev/null 2>&1 || true

if ! command -v wasm-pack >/dev/null 2>&1; then
  cargo install wasm-pack --locked
fi

wasm-pack build \
  --target web \
  --release \
  --out-dir "$ROOT/wasm/pkg" \
  -- \
  --no-default-features

echo "Wasm demo: open sdks/wasm/index.html via a static server (pkg/ must be co-located)."
