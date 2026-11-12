Trigger scripts that reproduced a finding, copied from the hunt's scratch
directory unchanged. They call `.libPaths()` on a scratch library, so edit
that line, or delete it to use an installed zuutf at commit 7ec8d2b.
`coordinator-rerun.R` re-runs every finding in one script.
