# Concurrent `git annex get` from same origin fails on shared filesystem

## Summary

When two independent git-annex clones simultaneously `git annex get` the same
key from the same origin repository on a shared parallel filesystem, one
succeeds and the other fails with "failed to retrieve content from remote" /
"Unable to access these remotes: origin". All retries fail immediately.

## Environment

- git-annex version: 10.20250630
- Filesystem: Dartmouth Discovery cluster — source repo on shared parallel FS
  (`/dartfs`, likely Lustre/GPFS), clones on `/scratch`
- Does NOT reproduce when both repos are on the same local filesystem (ext4/btrfs)
- Does NOT reproduce when source and clones are on the same shared FS

## Reproducer

Two scripts at: [TODO: link to repo]

```bash
# Setup: create a source repo with a 500MB annexed file
cd annex-only
./setup.sh

# Test: clone twice, concurrent git annex get --debug
./test_concurrent_annex_get.sh 2 /scratch/<user>/test/
```

### What the scripts do

**setup.sh:**
```bash
git init source && cd source
git annex init "source"
git config annex.dotfiles true
dd if=/dev/urandom of=.datalad/environments/bids-mriqc/image bs=1M count=500
git annex add .datalad/environments/bids-mriqc/image
git commit -m "Add file"
```

**test_concurrent_annex_get.sh:**
```bash
git clone "$SOURCE" clone_1 && (cd clone_1 && git annex init)
git clone "$SOURCE" clone_2 && (cd clone_2 && git annex init)
# Both clones have origin pointing to the same source repo path

git annex get --debug .datalad/environments/bids-mriqc/image  # in clone_1, backgrounded
git annex get --debug .datalad/environments/bids-mriqc/image  # in clone_2, backgrounded
wait
```

## Observed behavior

One clone succeeds, the other fails. The failing clone's `annex.retry=3` retries
all fail within seconds (no data is ever transferred):

```
clone_1 starts git annex get
clone_2 starts git annex get
clone_1 FAILS after ~3.6s:
  "failed to retrieve content from remote" (x3)
  "Unable to access these remotes: origin"
clone_2 succeeds after ~17s (transfers full 5GB)
```

## Expected behavior

Both clones should successfully retrieve the content. They are independent
repositories with separate `.git` directories. The source repo is only being
read from, not written to.

## Additional context

This was discovered via DataLad/BABS, where SLURM array jobs clone a dataset
and concurrently fetch a container image from the same source. The issue is
in the git-annex layer — we have reproduced it without DataLad using plain
`git clone` + `git annex get`.

On local filesystems, git-annex uses `cp --reflink=always` for the transfer,
which succeeds concurrently. On the cluster's shared filesystem, the transfer
mechanism may differ (reflink not supported), and that's where the contention
appears.

### What we've ruled out

- Not file-size dependent (500MB and 5GB both fail)
- Not DataLad-specific (reproduces with pure git-annex)
- Not related to RIA stores or special remotes (happens with plain git remote)
- Not a permissions issue (both clones can individually get the file fine when
  run sequentially)
