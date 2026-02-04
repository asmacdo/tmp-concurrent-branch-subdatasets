#!/bin/bash
set -eu

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$BASEDIR/playground"

if [ -d "$PLAYGROUND/source" ]; then
    echo "playground/source already exists, skipping setup"
    exit 0
fi

mkdir -p "$PLAYGROUND"
cd "$PLAYGROUND"

# Create source repo with git-annex
git init source
cd source
git annex init "source"
git config annex.dotfiles true

# Create 500MB fake container image
mkdir -p .datalad/environments/bids-mriqc
dd if=/dev/urandom of=.datalad/environments/bids-mriqc/image bs=1M count=500
git annex add .datalad/environments/bids-mriqc/image
git commit -m "Add fake 500MB container image"

echo "Setup complete. Source repo at: $PLAYGROUND/source"
