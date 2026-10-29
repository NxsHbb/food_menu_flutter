#!/bin/sh
# Point git at the repo's versioned hooks. Run once per clone.
set -e
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
chmod +x .githooks/*
echo "hooksPath -> $(git config core.hooksPath)"
