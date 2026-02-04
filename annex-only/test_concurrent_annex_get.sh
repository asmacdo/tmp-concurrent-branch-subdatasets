#!/bin/bash
set -eu -o pipefail

N="${1:-2}"
CLONEDIR="${2:-}"

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$BASEDIR/playground"
SOURCE="$PLAYGROUND/source"

if [ -n "$CLONEDIR" ]; then
    TESTDIR="$CLONEDIR/test_annex_$$"
else
    TESTDIR="$PLAYGROUND/test_annex_$$"
fi

mkdir -p "$TESTDIR"
cd "$TESTDIR"

echo "=== Concurrent git annex get test (N=$N) ==="
echo "Source: $SOURCE"
echo "Test dir: $TESTDIR"
echo ""

echo "Cloning $N copies..."
for i in $(seq 1 "$N"); do
    git clone "$SOURCE" "clone_$i"
    (cd "clone_$i" && git annex init "clone_$i")
done

echo ""
echo "Starting $N concurrent git annex get --debug..."
pids=()
for i in $(seq 1 "$N"); do
    ( cd "clone_$i" && git annex get --debug .datalad/environments/bids-mriqc/image 2>&1 \
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
