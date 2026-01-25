#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/release.sh 0.1.3
#
# Does:
# - Updates src/version.cr (VERSION = "x.y.z")
# - Commits the bump
# - Tags vX.Y.Z
# - Pushes main + tag

VERSION="${1:-}"

if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>  (e.g. $0 0.1.3)"
  exit 2
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: version must look like SemVer: X.Y.Z (e.g. 0.1.3)"
  exit 2
fi

if [[ ! -f src/version.cr ]]; then
  echo "ERROR: src/version.cr not found"
  exit 1
fi

# Ensure clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is not clean. Commit/stash first."
  git status --porcelain
  exit 1
fi

# Ensure on main (optional guard)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${BRANCH}" != "main" ]]; then
  echo "ERROR: you are on '${BRANCH}', expected 'main'"
  exit 1
fi

# Ensure tag doesn't already exist
TAG="v${VERSION}"
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "ERROR: tag ${TAG} already exists"
  exit 1
fi

# Update src/version.cr in-place
tmpfile="$(mktemp)"
awk -v ver="${VERSION}" '
  BEGIN { updated=0 }
  {
    if ($0 ~ /VERSION\s*=\s*"/) {
      sub(/VERSION\s*=\s*"[^"]*"/, "VERSION = \"" ver "\"")
      updated=1
    }
    print
  }
  END {
    if (updated == 0) {
      exit 3
    }
  }
' src/version.cr > "${tmpfile}" || {
  rc=$?
  if [[ $rc -eq 3 ]]; then
    echo "ERROR: could not find VERSION = \"...\" in src/version.cr"
  fi
  rm -f "${tmpfile}"
  exit 1
}
mv "${tmpfile}" src/version.cr

# Commit
git add src/version.cr
git commit -m "Release ${TAG}"

# Tag
git tag "${TAG}"

# Push branch + tag
git push origin main
git push origin "${TAG}"

echo "✅ Released ${TAG}"
echo "   GitHub Actions will build and publish release assets."
