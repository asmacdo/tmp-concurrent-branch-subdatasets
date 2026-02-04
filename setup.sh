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

# Create a standalone container source dataset (like handmade-containers)
datalad create -c text2git container_source
mkdir -p container_source/.datalad/environments/bids-mriqc
dd if=/dev/urandom of=container_source/.datalad/environments/bids-mriqc/image bs=1M count=5000
datalad -C container_source save -m "Add fake 5GB container image"

# Create top-level analysis dataset
datalad create -c text2git source_ds

# Clone the container source as a subdataset (like BABS does with dlapi.install)
# This records the source URL in .gitmodules so clones can resolve annex content
datalad clone -d source_ds "$PLAYGROUND/container_source" source_ds/containers
datalad -C source_ds save -m "Register container source as subdataset"

# Register container pointing into subdataset (BABS style)
datalad -C source_ds containers-add bids-mriqc \
    --image containers/.datalad/environments/bids-mriqc/image \
    --call-fmt 'echo {img} {cmd}'

# Create input RIA for top-level dataset only (no storage sibling, matching BABS)
# The containers subdataset is NOT pushed to the RIA. This forces clones to
# fall back to the .gitmodules URL (container_source) when installing the
# subdataset, which is how they get access to the annex content.
datalad -C source_ds create-sibling-ria -s ria --new-store-ok --alias source_ds \
    --storage-sibling off \
    "ria+file://$PLAYGROUND/ria_store"
datalad -C source_ds push --to ria

echo "Setup complete. RIA store at: $PLAYGROUND/ria_store"
echo "Container source at: $PLAYGROUND/container_source"
