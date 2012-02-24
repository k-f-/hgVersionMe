# Versioning between branches in Mercurial

## Purpose

Wrote this for a project some friends and I worked on.
All work in our case was done in "Default" with merges to Release, and then possibly Deploy.

## Requirements

Because of how Mercurial handles tags between branches you must add these lines to your *hgrc*

```bash
vim .hg/hgrc
```
```bash
[merge-tools]
merge-tags.executable = cat
merge-tags.args = $local $other | sort -u >> $output

[merge-patterns]
.hgtags = merge-tags
```

