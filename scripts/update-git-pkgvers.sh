#!/usr/bin/env bash

# Update pkgver in all *-git package directories.
#
# What it does:
# - Iterates over directories matching *-git containing a PKGBUILD
# - Ensures sources are fetched/extracted so pkgver() can run
# - Computes the new pkgver using makepkg
# - Updates the PKGBUILD's pkgver= line
# - Regenerates .SRCINFO to reflect the new version
#
# Notes:
# - Requires Arch packaging tools (makepkg) and VCS clients.
# - Does not install dependencies (uses --nodeps), nor builds packages.
# - Safe to run from the repo root. Pass an optional path to limit scope.

set -euo pipefail

ROOT_DIR=${1:-.}

shopt -s nullglob

updated=0
uptodate=0
skipped=0
failed=0

find_candidates() {
  # Echo paths to PKGBUILD files under *-git directories at depth 1
  for p in "$ROOT_DIR"/*-git/PKGBUILD; do
    [ -f "$p" ] && echo "$p"
  done
}

echo "Scanning for *-git packages under: $ROOT_DIR"

any=0
for pkgb in $(find_candidates); do
  any=1
  dir=$(dirname "$pkgb")
  echo "==> Processing: $dir"

  (
    set -euo pipefail
    cd "$dir"

    if ! grep -qE '^pkgver\s*\(\)' PKGBUILD; then
      echo "    No pkgver() function found; skipping"
      exit 4
    fi

    # Current pkgver from PKGBUILD (best-effort parse)
    current_pkgver=$(awk -F= 'BEGIN{OFS="="} /^\s*pkgver\s*=/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/["\'\']/ , "", $2); print $2; exit}' PKGBUILD || true)
    current_pkgver=${current_pkgver:-""}

    # Fetch/extract sources so pkgver() has VCS data available
    if ! makepkg -o --nodeps --noconfirm >/dev/null 2>&1; then
      echo "    makepkg -o failed; attempting without quiet flags"
      if ! makepkg -o --nodeps --noconfirm; then
        echo "    Failed to prepare sources"
        exit 1
      fi
    fi

    # Compute new pkgver using makepkg's understanding of the PKGBUILD
    new_pkgver=$(makepkg --printsrcinfo | awk '/^pkgver = /{print $3; exit}')
    if [[ -z "${new_pkgver:-}" ]]; then
      echo "    Could not determine new pkgver; skipping"
      exit 1
    fi

    if [[ "${current_pkgver}" == "${new_pkgver}" ]]; then
      echo "    Up-to-date: ${current_pkgver}"
      exit 3
    fi

    # Update the pkgver= line in PKGBUILD
    tmpfile=$(mktemp)
    awk -v ver="$new_pkgver" '
      BEGIN{done=0}
      /^\s*pkgver\s*=/{ if(!done){ print "pkgver=" ver; done=1; next } }
      { print }
    ' PKGBUILD > "$tmpfile"
    mv "$tmpfile" PKGBUILD

    # Regenerate .SRCINFO to reflect the new version
    makepkg --printsrcinfo > .SRCINFO

    echo "    Updated: ${current_pkgver:-<unset>} -> ${new_pkgver}"
  )

  rc=$?
  case "$rc" in
    0) ((updated++)) ;;
    3) ((uptodate++)) ;;
    4) ((skipped++)) ;;
    *) ((failed++)) ;;
  esac
done

if [[ $any -eq 0 ]]; then
  echo "No *-git package directories with PKGBUILD found under: $ROOT_DIR"
  exit 0
fi

echo ""
echo "Summary:"
echo "  Updated:   $updated"
echo "  Up-to-date:$uptodate"
echo "  Skipped:   $skipped"
echo "  Failed:    $failed"

exit 0

