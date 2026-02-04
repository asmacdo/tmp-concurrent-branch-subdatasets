#!/bin/bash
set -eu

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$BASEDIR/playground"

if [ -d "$PLAYGROUND/source_ds" ]; then
    echo "playground/source_ds already exists, skipping setup"
    exit 0
fi

mkdir -p "$PLAYGROUND"
cd "$PLAYGROUND"

# Create top-level dataset
datalad create -c text2git source_ds

# Create containers subdataset
datalad create -c text2git -d source_ds source_ds/containers

# Create 5GB fake container image in subdataset annex
mkdir -p source_ds/containers/.datalad/environments/bids-mriqc
dd if=/dev/urandom of=source_ds/containers/.datalad/environments/bids-mriqc/image bs=1M count=5000

# Save in subdataset, then parent
datalad -C source_ds/containers save -m "Add fake 5GB container image"
datalad -C source_ds save -m "Update containers subdataset"

# Register container pointing into subdataset (BABS style)
datalad -C source_ds containers-add bids-mriqc \
    --image containers/.datalad/environments/bids-mriqc/image \
    --call-fmt 'echo {img} {cmd}'

# Create RIA store and push everything
datalad -C source_ds create-sibling-ria -s ria --new-store-ok --alias source_ds \
    "ria+file://$PLAYGROUND/ria_store"
datalad -C source_ds/containers create-sibling-ria -s ria --alias containers \
    "ria+file://$PLAYGROUND/ria_store"
datalad -C source_ds/containers push --to ria
datalad -C source_ds push --to ria

echo "Setup complete. RIA store at: $PLAYGROUND/ria_store"
