#!/usr/bin/env bash
# Fetches the manga-ocr ONNX model + vocab into MangaMining/Resources/.
# The model is ~250MB; do not commit it to the repo.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO_ROOT/MangaMining/Resources"
mkdir -p "$DEST"

MODEL_URL="${MODEL_URL:-https://huggingface.co/mayocream/manga-ocr-onnx/resolve/main/model.onnx}"
VOCAB_URL="${VOCAB_URL:-https://huggingface.co/mayocream/manga-ocr-onnx/resolve/main/vocab.txt}"

echo "→ Downloading model to $DEST/manga-ocr.onnx"
curl -L --fail -o "$DEST/manga-ocr.onnx" "$MODEL_URL"

echo "→ Downloading vocab to $DEST/vocab.txt"
curl -L --fail -o "$DEST/vocab.txt" "$VOCAB_URL"

echo "✓ Done. Re-run: xcodegen generate"
