#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

upstream_remote="upstream"
if ! git remote | grep -q "^upstream$"; then
    upstream_remote="origin"
fi

echo "==> Fetching updates from upstream ($upstream_remote/main)..."
git fetch "$upstream_remote" main

echo "==> Merging upstream updates into your branch..."
git merge "$upstream_remote/main" --no-edit

echo "==> Running checks..."
make check

echo "==> Installing updated DiaTweaks into Dia..."
./install.sh --yes

echo "==> Successfully synced with upstream!"
