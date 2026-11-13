#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

upstream_remote="upstream"
if ! git remote | grep -q "^upstream$"; then
    upstream_remote="origin"
fi

PRS=("252" "310" "201" "428" "369")

echo "==> Fetching updates from upstream ($upstream_remote/main)..."
git fetch "$upstream_remote" main

for pr in "${PRS[@]}"; do
    echo "==> Fetching PR #$pr from $upstream_remote..."
    git fetch "$upstream_remote" "+pull/$pr/head:pr-$pr" 2>/dev/null || true
done

echo "==> Merging upstream updates into your branch..."
git merge "$upstream_remote/main" --no-edit

for pr in "${PRS[@]}"; do
    echo "==> Merging PR #$pr..."
    git merge "pr-$pr" --no-edit 2>/dev/null || true
done

echo "==> Running checks..."
make check

echo "==> Installing updated DiaTweaks into Dia..."
./install.sh --yes

if git remote | grep -q "^origin$"; then
    echo "==> Pushing to origin/my-build..."
    git push origin my-build 2>/dev/null || true
fi

echo "==> Successfully synced with upstream!"
