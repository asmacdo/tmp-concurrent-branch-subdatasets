#!/bin/bash
set -eu -o pipefail

N="${1:-2}"
CLONEDIR="${2:-}"

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$BASEDIR/playground"
RIA_STORE="$PLAYGROUND/ria_store"
DSID=$(datalad -C "$PLAYGROUND/source_ds" -f'{infos[dataset][id]}' wtf -S dataset)

if [ -n "$CLONEDIR" ]; then
    TESTDIR="$CLONEDIR/test_get_$$"
else
    TESTDIR="$PLAYGROUND/test_get_$$"
fi

mkdir -p "$TESTDIR"
cd "$TESTDIR"

echo "=== Concurrent datalad get test (N=$N) ==="
echo "Cloning $N copies from RIA..."

for i in $(seq 1 "$N"); do
    datalad clone "ria+file://$RIA_STORE#${DSID}" "clone_$i"
done

echo "Starting $N concurrent datalad get..."
export GIT_ANNEX_DEBUG=1
pids=()
for i in $(seq 1 "$N"); do
    ( datalad -l debug -C "clone_$i" get containers/.datalad/environments/bids-mriqc/image 2>&1 \
        | while IFS= read -r line; do printf "%s [clone_%s] %s\n" "$(date +%H:%M:%S.%3N)" "$i" "$line"; done ) &
    pids+=($!)
done

echo "Waiting for all jobs..."
failures=0
for i in $(seq 1 "$N"); do
    if wait "${pids[$((i-1))]}"; then
        echo "  clone_$i: OK"
    else
        echo "  clone_$i: FAILED"
        failures=$((failures + 1))
    fi
done

echo ""
if [ "$failures" -eq 0 ]; then
    echo "RESULT: All $N concurrent gets succeeded"
else
    echo "RESULT: $failures/$N failed"
fi

echo "Cleanup: chmod -R u+w $TESTDIR && rm -rf $TESTDIR"

exit "$failures"
