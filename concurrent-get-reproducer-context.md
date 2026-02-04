# Context: Concurrent datalad get failure reproducer

## Problem

When BABS submits SLURM array jobs, each job clones a dataset from a RIA store
and then needs to `datalad get` a container image (a ~5GB .sif file stored in a
`containers/` subdataset). When 2+ jobs run concurrently and try to `datalad get`
the same file from the same RIA source simultaneously, one succeeds and the
others fail with:

```
get(error): containers/.datalad/environments/bids-mriqc/image (file)
[failed to retrieve content from remote
failed to retrieve content from remote
failed to retrieve content from remote]
```

This is 100% reproducible: submit 2 array jobs, 1 succeeds, 1 fails. Every time.

## Note: Previous architecture

previously babs used datalad run -i <pathtocontainerimage> rather than containers-run directly. This
seemed to not have the problem.

## Architecture

The BABS job flow:
1. Each SLURM array task clones from a RIA store: `datalad clone ria+file://...#<dataset-id> ds`
2. Each clone installs the `containers/` subdataset and fetches the container image
3. Each clone runs `datalad containers-run` using that container
4. Results are pushed back via output RIA

The RIA store lives on a shared parallel filesystem (`/dartfs/rc/lab/...`).
Each job clones onto the compute node's local `/scratch` filesystem.

## What we've tried

### 1. `--reckless ephemeral`
Yarik (datalad developer) suggested this. It creates clones that share annex
content via symlinks/hardlinks with the source, avoiding redundant fetches.

**Result:** Fails on Discovery cluster's /scratch filesystem:
```
git-annex: .git/annex: createDirectory: already exists (File exists)
```
Likely related to ACL issues on this filesystem (many `Failed to instantiate ACL`
warnings during all datalad operations on /scratch).

### 2. `git worktree`
Also suggested by Yarik. One base clone fetches the container, then per-job
worktrees share the same .git/annex objects.

**Result:** Worktrees don't initialize subdatasets. The `containers/` directory
is empty in each worktree because `containers/` is a separate git repo
(datalad subdataset). `git worktree` only operates on the top-level repo.
Each worktree would still need `datalad get` for the containers subdataset,
defeating the purpose.

### 3. Explicit `datalad get` before `containers-run`
Added an explicit `datalad get containers/.datalad/environments/bids-mriqc/image`
step before `datalad containers-run`.

**Result:** Same concurrent failure. The `datalad get` itself is what fails
when two jobs try it at the same time.

## Goal: create a reproducer script

We want a self-contained script that:
1. Creates a datalad dataset with a subdataset containing a large-ish annex file
   (simulating the container image)
2. Sets up a RIA store
3. Launches 2 concurrent clones from the RIA store
4. Each clone tries to `datalad get` the same file from the subdataset
5. Demonstrates that one fails

This should ideally run locally (no SLURM needed) using `&` for concurrency.
However, the `--reckless ephemeral` failure may only reproduce on the cluster
filesystem. The concurrent get failure should reproduce anywhere.

## Relevant paths on Discovery cluster (for reference only)

- RIA store: `ria+file:///dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/tmp-babs-container-run-testing/babs-generated/input_ria`
- Dataset ID: `ee32ee41-fe2b-4d91-a188-c802c0a27a1f`
- Analysis dataset: `/dartfs/rc/lab/D/DBIC/DBIC/CON/asmacdo/tmp-babs-container-run-testing/babs-generated/analysis`
- Container path within dataset: `containers/.datalad/environments/bids-mriqc/image`

## Test script and output

See `/home/austin/devel/babs/yohmsg.md` for a full test script run on cluster (ephemeral + worktree tests) and output.
