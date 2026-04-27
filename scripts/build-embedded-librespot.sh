#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFI_MANIFEST="$ROOT_DIR/Vendor/orbisonic-librespot-ffi/Cargo.toml"
TARGET_DIR="$ROOT_DIR/.build/orbisonic-librespot-rust"
ARTIFACT_DIR="$ROOT_DIR/.build/orbisonic-librespot"
STATIC_LIB="$TARGET_DIR/release/liborbisonic_librespot_ffi.a"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is required to build the embedded librespot module." >&2
  echo "Install Rust 1.85 or newer, then run this script again." >&2
  exit 1
fi

if ! command -v rustc >/dev/null 2>&1; then
  echo "rustc is required to build the embedded librespot module." >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"

CARGO_TARGET_DIR="$TARGET_DIR" cargo build \
  --manifest-path "$FFI_MANIFEST" \
  --release

cp "$STATIC_LIB" "$ARTIFACT_DIR/"

cat <<EOF
Built embedded librespot static library:
  $ARTIFACT_DIR/$(basename "$STATIC_LIB")

SwiftPM integration:
  Package.swift links this archive into the Orbisonic target with ORBISONIC_ENABLE_EMBEDDED_LIBRESPOT.
EOF
