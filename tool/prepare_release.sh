#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit outstanding work before preparing a release.' >&2; exit 1; }
python3 tool/release_version.py bump "${1:-patch}"
read -r version build < <(python3 tool/release_version.py check)
git add pubspec.yaml
git commit -m "Prepare release $version ($build)"
echo "Review this commit, merge it to the repository default branch, then tag that commit v$version and push the tag."
