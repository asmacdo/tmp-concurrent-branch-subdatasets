#!/bin/bash
set -eu

N="${1:-2}"

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$BASEDIR/playground"
RIA_STORE="$PLAYGROUND/ria_store"
DSID=$(datalad -C "$PLAYGROUND/source_ds" -f'{infos[dataset][id]}' wtf -S dataset)
TESTDIR="$PLAYGROUND/test_get_$$"

mkdir -p "$TESTDIR"
cd "$TESTDIR"

echo "=== Concurrent datalad get test (N=$N) ==="
echo "Cloning $N copies from RIA..."

for i in $(seq 1 "$N"); do
    datalad clone "ria+file://$RIA_STORE#${DSID}" "clone_$i"
done

echo "Starting $N concurrent datalad get..."
pids=()
for i in $(seq 1 "$N"); do
    datalad -C "clone_$i" get containers/.datalad/environments/bids-mriqc/image \
        > "clone_${i}.log" 2>&1 &
    pids+=($!)
done

echo "Waiting for all jobs..."
failures=0
for i in $(seq 1 "$N"); do
    if wait "${pids[$((i-1))]}"; then
        echo "  clone_$i: OK"
    else
        echo "  clone_$i: FAILED"
        cat "clone_${i}.log"
        failures=$((failures + 1))
    fi
done

echo ""
if [ "$failures" -eq 0 ]; then
    echo "RESULT: All $N concurrent gets succeeded"
else
    echo "RESULT: $failures/$N failed"
fi

# Cleanup
cd "$PLAYGROUND"
chmod -R u+w "$TESTDIR"
rm -rf "$TESTDIR"

exit "$failures"
