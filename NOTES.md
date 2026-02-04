# Concurrent datalad get reproducer - progress notes

## Setup (matching BABS architecture)
- `playground/container_source`: standalone dataset with 5GB fake image in annex
- `playground/source_ds`: analysis dataset, containers subdataset cloned from container_source
- Container registered BABS-style: `image = containers/.datalad/environments/bids-mriqc/image`
- Input RIA: top-level dataset only, **no storage sibling** (`--storage-sibling off`)
- Containers subdataset is NOT in the RIA — clones fall back to .gitmodules URL

## Key findings

### What doesn't matter
- File size (50MB, 500MB, 5GB all behave the same)
- `datalad get` vs `containers-run` (same behavior)
- Local filesystem (never reproduces locally)

### What does matter
- **No storage sibling in RIA** — forces subdataset clone to fall back to container_source
- **Cross-filesystem** — RIA + container_source on shared lab FS, clones on /scratch
- **Concurrent access to same source repo** — multiple git-annex gets from same origin

### Root cause (narrowed down)
Two concurrent `datalad get` operations both clone the containers subdataset
from the same source (container_source on shared FS). Both set `origin` to
the same path. When both then do `git-annex get` from that same origin
simultaneously, one fails with "failed to retrieve content from remote" (3x).
The first to finish succeeds; the other fails.

## Reproduction
```bash
# On lab FS:
./setup.sh

# Clones on /scratch, RIA + container_source on lab FS:
./test_concurrent_get.sh 2 /scratch/f006rq8/concurrency-tests/
```

## Results
- **Cluster, cross-FS, BABS-like setup:** REPRODUCED — clone_1 OK, clone_2 FAILED
- All local tests: PASS (cannot reproduce locally)
- All tests with storage sibling enabled: PASS

## Next steps
- Investigate git-annex locking during concurrent get from same source repo
- Try with retry logic / annex.retry setting
- Consider workaround: pre-fetch container in a single job before array
