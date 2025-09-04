#!/usr/bin/env bash
# bump-selected-git.sh
# Only process packages from pkgs[] that ALREADY end with -git.
# Refresh sources, run pkgver() (no build), optional --inplace to rewrite pkgver=.

set -euo pipefail

INPLACE=0
SKIP_CLEAN=0
NOCONFIRM=1

usage() {
  cat <<EOF
Usage: $0 [--inplace] [--no-clean] [--confirm]

  --inplace    Rewrite the pkgver= line in PKGBUILD (use with care).
  --no-clean   Do not delete ./src and ./pkg before running makepkg.
  --confirm    Do NOT pass --noconfirm to makepkg (ask on prompts).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inplace) INPLACE=1; shift ;;
    --no-clean) SKIP_CLEAN=1; shift ;;
    --confirm) NOCONFIRM=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Refusing to run as root. Use an unprivileged user." >&2
  exit 1
fi

MAKEPKG_FLAGS=(-d --nocheck)
[[ $NOCONFIRM -eq 1 ]] && MAKEPKG_FLAGS+=(--noconfirm)

# -------------------------------------------------------------------
# Your package selection (unchanged)
pkgs=(
  # Layer 1
  telepathy-farstream
  qt5-pim-git
  properties-cpp
  dbus-test-runner
  qdjango-git
  buteo-syncfw-qml-git
  humanity-icon-theme
  libaccounts-qt5
  qmenumodel-git
  geonames-git
  libqofono-qt5
  ofono-git
  wlcs
  deviceinfo-git
  lomiri-settings-components
  lomiri-schemas
  persistent-cache-cpp
  # # Layer 2
  hfd-service
  mir
  process-cpp
  suru-icon-theme-git
  telepathy-qt-git
  click-git
  libqtdbustest-git
  repowerd-git
  # # Layer 3
  dbus-cpp
  libqtdbusmock-git
  lomiri-history-service-git
  libusermetrics-git
  lomiri-api-git
  # # Layer 4
  biometryd-git
  lomiri-download-manager-git
  lomiri-app-launch-git
  lomiri-ui-toolkit-git
  gmenuharness-git
  lomiri-thumbnailer
  # # Layer 5
  lomiri-url-dispatcher-git
  # # Layer 6
  libayatana-common-git
  lomiri-indicator-network-git
  lomiri-telephony-service-git
  lomiri-address-book-service-git
  lomiri-content-hub-git
  lomiri-system-settings
  qtmir-git
  # # Layer 7
  ayatana-indicator-messages
  ayatana-indicator-datetime-git
  lomiri
  # # Layer 8
  lomiri-notifications-git
  lomiri-session
)
# -------------------------------------------------------------------

processed_any=0

for name in "${pkgs[@]}"; do
  # skip blanks and comments
  [[ -n "${name// }" ]] || continue
  [[ "${name:0:1}" == "#" ]] && continue

  # only -git packages
  if [[ ! "$name" =~ -git$ ]]; then
    echo "-- Skipping '${name}' (not a -git entry)"
    continue
  fi

  dir="./$name"
  if [[ ! -f "$dir/PKGBUILD" ]]; then
    echo "-- Skipping '${name}': no '$dir/PKGBUILD' here"
    continue
  fi

  processed_any=1
  echo "================================================================================"
  echo ">> Entering: $dir"
  pushd "$dir" >/dev/null

  # Optional clean for fresh pkgver()
  if [[ $SKIP_CLEAN -eq 0 ]]; then
    rm -rf src pkg
  fi

  # 1) Refresh VCS sources (no build)
  if ! makepkg -od "${MAKEPKG_FLAGS[@]}"; then
    echo "!! makepkg -od failed in $dir (continuing...)"
  fi

  # 2) Run prepare() + pkgver() (still no build)
  if ! makepkg --nobuild "${MAKEPKG_FLAGS[@]}"; then
    echo "!! makepkg --nobuild failed in $dir (continuing...)"
  fi

  # 3) Optionally update pkgver= in PKGBUILD using pkgver()
  if [[ $INPLACE -eq 1 ]]; then
    export srcdir="$PWD/src" pkgdir="$PWD/pkg" startdir="$PWD"
    newver="$(
      bash -c '
        set -euo pipefail
        source ./PKGBUILD
        declare -F pkgver >/dev/null || exit 40
        printf "%s" "$(pkgver)"
      ' 2>/dev/null || true
    )"
    if [[ -n "${newver:-}" ]]; then
      sed -Ei "0,/^pkgver=.*/s//pkgver=${newver}/" PKGBUILD
      echo ">> Updated PKGBUILD pkgver= to: ${newver}"
    else
      echo "!! Could not compute new pkgver() (leaving PKGBUILD unchanged)"
    fi
  fi

  popd >/dev/null
done

if [[ $processed_any -eq 0 ]]; then
  echo "No matching -git package directories found under $(pwd)."
fi

echo "Done."
