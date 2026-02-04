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
- Whether datalad is involved at all (pure git-annex reproduces it)

### What DOES matter
- **No storage sibling in RIA** — forces subdataset clone to fall back to container_source
- **Multiple clones with origin pointing to same source repo** — concurrent git-annex get
- **Cluster filesystem** — reproduces on Discovery cluster (/dartfs + /scratch), not locally
  - Local filesystem uses `cp --reflink=always` which succeeds concurrently
  - Cluster likely uses rsync or cp without reflink, which contends

### Root cause (narrowed down)
When two git-annex processes concurrently `git annex get` the same key from the
same origin repo, one fails with "failed to retrieve content from remote" and
"Unable to access these remotes: origin". The failing process retries 3 times
(annex.retry=3) and fails all 3 within ~3.6 seconds — it never transfers any data.
The succeeding process takes ~17 seconds to transfer 5GB normally.

### Debug output details (from datalad debug run on cluster)
```
15:36:23.490  clone_2 starts git annex get (annex.retry=3)
15:36:23.532  clone_1 starts git annex get (annex.retry=3)
15:36:27.159  clone_1 FAILS (3.6s, all 3 retries failed instantly)
              "Unable to access these remotes: origin"
15:36:40.440  clone_2 succeeds (17s, transferred 5GB)
```

git-annex's own --debug output not yet captured on cluster (annex-only reproducer
created but needs to be run there).

## Reproduction

### Full datalad reproducer (requires cluster)
```bash
# On lab FS (/dartfs):
./setup.sh
# Clones on /scratch:
./test_concurrent_get.sh 2 /scratch/f006rq8/concurrency-tests/
```

### Minimal annex-only reproducer (in annex-only/)
```bash
cd annex-only
./setup.sh
./test_concurrent_annex_get.sh 2 /scratch/f006rq8/concurrency-tests/
```

## Results summary
| Test | Location | Result |
|------|----------|--------|
| Local clone, concurrent get (any size) | local | PASS |
| RIA clone + storage sibling, concurrent get | local | PASS |
| RIA clone + storage sibling, concurrent get | cluster cross-FS | PASS |
| RIA clone + storage sibling, concurrent containers-run | cluster cross-FS | PASS |
| RIA clone, NO storage sibling, concurrent get | local | PASS |
| RIA clone, NO storage sibling, concurrent get | cluster cross-FS | **FAIL** |
| RIA clone, NO storage sibling, concurrent containers-run | cluster cross-FS | **FAIL** |

## Workaround options
1. Add storage sibling to input RIA (proven to work)
2. Pre-fetch container in a single setup job before submitting array
3. Retry logic with backoff (annex.retry=3 already fails, may need longer delay)
