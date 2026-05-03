#!/usr/bin/env bash
# Fetches the manga-ocr ONNX model + tokenizer assets into MangaMining/Resources/.
# Total ~250MB; do not commit to the repo.
#
# The mayocream/manga-ocr-onnx repo provides an encoder + decoder split (Vision
# Transformer encoder, GPT-style decoder) plus the tokenizer/preprocessor JSON
# config and the vocab. All files go into the bundle so MangaOCRRunner can find
# them at runtime.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO_ROOT/MangaMining/Resources"
mkdir -p "$DEST"

BASE="${MODEL_BASE_URL:-https://huggingface.co/mayocream/manga-ocr-onnx/resolve/main}"

FILES=(
    "encoder_model.onnx"
    "decoder_model.onnx"
    "vocab.txt"
    "tokenizer_config.json"
    "preprocessor_config.json"
    "generation_config.json"
    "config.json"
    "special_tokens_map.json"
)

for f in "${FILES[@]}"; do
    echo "→ $f"
    curl -L --fail --progress-bar -o "$DEST/$f" "$BASE/$f"
done

echo "✓ Fetched $(ls -1 "$DEST" | grep -v '^\.' | wc -l | tr -d ' ') files into $DEST"
echo "  Re-run: xcodegen generate"
