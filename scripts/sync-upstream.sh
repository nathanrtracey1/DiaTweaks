#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

echo "==> Fetching updates from upstream (origin/main)..."
git fetch origin main

echo "==> Merging upstream updates into your branch..."
git merge origin/main --no-edit

echo "==> Running checks..."
make check

echo "==> Installing updated DiaTweaks into Dia..."
./install.sh --yes

echo "==> Successfully synced with upstream!"
