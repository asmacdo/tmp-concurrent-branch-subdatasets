# Concurrent datalad get reproducer - progress notes

## Setup so far
- Source dataset: `playground/source_ds` (text2git)
- Subdataset: `playground/source_ds/containers` (text2git)
- 50MB random file at `containers/.datalad/environments/bids-mriqc/image` (in subdataset annex)
- `datalad containers-add` also put image in parent annex at `.datalad/environments/bids-mriqc/image`
- Container registered with `--call-fmt 'echo {img} {cmd}'`

## Key insight
- Old BABS: `datalad run -i containers/.datalad/...` — image fetched from subdataset annex
- New BABS (Austin's branch): `containers-add` + `containers-run` — image in parent annex
- Old approach didn't hit concurrent failure; new approach does
- Difference might be subdataset-annex vs parent-annex fetch path

## Test plan
1. Clone source_ds twice (local, no RIA), concurrent `datalad get` of parent-annex path
2. Clone source_ds twice (local, no RIA), concurrent `datalad get` of subdataset path
3. If neither fails locally, add RIA store and repeat
4. Compare `datalad run -i` vs `datalad containers-run`

## Results so far
- **Local clone + concurrent get (500MB, subdataset path):** PASS — both succeed
- **RIA clone + concurrent get (500MB, subdataset path):** PASS — both succeed
- **RIA clone + concurrent get (5GB, subdataset path):** PASS — both succeed
- **RIA clone + concurrent containers-run (5GB, subdataset path):** PASS — both succeed

## Current step
- Need to try `datalad containers-run` concurrently, or try to identify what's different on cluster
