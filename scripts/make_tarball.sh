#!/bin/bash
# Build the release tarball from git-tracked files only (no drafts, data,
# local configs or archived material). Run from the repository root after
# committing:  bash scripts/make_tarball.sh [ref]
set -euo pipefail
ref="${1:-HEAD}"
out="DRS_VIM_code.tar.gz"
git archive --format=tar.gz --prefix=DRS_VIM/ -o "$out" "$ref"
echo "Wrote $out from $(git rev-parse --short "$ref"):"
tar tzf "$out" | sed 's/^/  /'
