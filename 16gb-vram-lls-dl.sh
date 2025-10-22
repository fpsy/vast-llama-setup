#!/usr/bin/env bash
set -euo pipefail

# URLs for the models
URLS=(
  "https://huggingface.co/unsloth/Qwen3-8B-128K-GGUF/resolve/main/Qwen3-8B-128K-UD-Q6_K_XL.gguf"
  "https://huggingface.co/unsloth/Qwen3-14B-128K-GGUF/resolve/main/Qwen3-14B-128K-UD-Q4_K_XL.gguf"
  "https://huggingface.co/unsloth/gpt-oss-20b-GGUF/resolve/main/gpt-oss-20b-F16.gguf"
)

# Download each model into the current directory
for url in "${URLS[@]}"; do
  fname=$(basename "$url")
  echo "Downloading $fname ..."
  wget -c --show-progress "$url" -O "$fname"
  echo "Saved: $fname"
done

echo "All downloads complete."

