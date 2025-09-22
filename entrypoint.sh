#!/bin/bash
set -e
cd /build


repo_full=$(cat ./repo)
repo_owner=$(echo $repo_full | cut -d/ -f1)
repo_name=$(echo $repo_full | cut -d/ -f2)
sed -i '/\[community\]/d' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
pacman-key --init
pacman -Syu --noconfirm --needed sudo git wget python
useradd builduser -m
chown -R builduser:builduser /build
git config --global --add safe.directory /build
sudo -u builduser gpg --recv-keys 38DBBDC86092693E
passwd -d builduser
printf 'builduser ALL=(ALL) ALL\n' | tee -a /etc/sudoers

cat ./gpg_key | base64 --decode | gpg --homedir /root/.gnupg --import
cat ./gpg_key | base64 --decode | gpg --homedir /home/builduser/.gnupg --import
rm ./gpg_key
echo "checking out buildusers key"
gpg --homedir /home/builduser/.gnupg --list-keys
echo "checking out root key"
gpg --homedir /root/.gnupg --list-keys

# add the ironrobin-lomiri repo to the end of /etc/pacman.conf
echo '[ironrobin-lomiri]' >> /etc/pacman.conf
echo 'Server = https://github.com/ironrobin/lomiri-packages/releases/download/packages' >> /etc/pacman.conf

sudo pacman-key --recv-keys 6ED02751500A833A
sudo pacman-key --lsign-key 6ED02751500A833A

sudo pacman -Sy
sudo pacman -S base-devel --noconfirm --needed

# Removed accountsservice-ubuntu from layer 1
# no content-hub. needed for mobile
pkgs=(
  # Layer 1
  telepathy-farstream
  qt5-pim-git
  properties-cpp
  dbus-test-runner
  qdjango-git
  buteo-syncfw-qml
  humanity-icon-theme
  libaccounts-qt5
  qmenumodel
  geonames
  libqofono-qt5
  ofono-git
  wlcs
  deviceinfo
  lomiri-settings-components
  lomiri-schemas
  persistent-cache-cpp
  ayatana-indicator-messages
  lomiri-wallpapers
  # Layer 2
  suru-icon-theme
  hfd-service
  mir
  process-cpp
  telepathy-qt-git
  click
  libqtdbustest
  repowerd
  # Layer 3
  dbus-cpp
  libqtdbusmock
  lomiri-history-service
  libusermetrics
  lomiri-api
  # Layer 4
  biometryd
  lomiri-download-manager-git
  lomiri-app-launch
  lomiri-ui-toolkit
  gmenuharness
  lomiri-thumbnailer
  lomiri-notifications
  # Layer 5
  # lomiri-url-dispatcher-git
  # # Layer 6
  # libayatana-common-git
  # lomiri-indicator-network
  # lomiri-telephony-service-git
  # lomiri-address-book-service-git
  # lomiri-system-settings
  # qtmir-git
  # # Layer 7
  # ayatana-indicator-datetime-git
  # lomiri
  # Layer 8
  # lomiri-session
)

for i in "${pkgs[@]}" ; do
  status=13
  git submodule update --init $i
  cd $i
  REPONAME="$repo_owner-lomiri"
  PKGNAME=$(basename $i)

  # Extract version from PKGBUILD
  PKGVERLINE=$(grep -E '^pkgver=' PKGBUILD)
  PKGVER="${PKGVERLINE#*=}"
  PKGRELLINE=$(grep -E '^pkgrel=' PKGBUILD)
  PKGREL="${PKGRELLINE#*=}"
  VERSION="${PKGVER}-${PKGREL}"

  if pacman -Si $PKGNAME &> /dev/null; then
    REPO_VERSION=$(pacman -Si $PKGNAME | grep Version | awk '{print $3}')
    echo "REPO_VERSION: $REPO_VERSION"
    echo "VERSION: $VERSION"
    echo "PKGNAME: $PKGNAME"
    if (( $(vercmp "$VERSION" "$REPO_VERSION") < 0 )); then
      echo "Package $PKGNAME of version $VERSION is older than the version ($REPO_VERSION) in the $REPONAME repo. Not building."
      sudo pacman -Swdd $PKGNAME --noconfirm --cachedir ./
    elif [ "$REPO_VERSION" == "$VERSION" ]; then
      echo "Package $PKGNAME of version $VERSION already exists in the $REPONAME repo. Not building."
      sudo pacman -Swdd $PKGNAME --noconfirm --cachedir ./
    else
      echo "Package $PKGNAME exists but with a different version ($REPO_VERSION) in the $REPONAME repo. Building new version $VERSION."
      sudo -u builduser bash -c 'export MAKEFLAGS=-j$(nproc) && makepkg --sign -s --noconfirm'||status=$?
    fi
  else
     echo "Package $PKGNAME does not exist in the $REPONAME repo. Adding it."
     sudo -u builduser bash -c 'export MAKEFLAGS=-j$(nproc) && makepkg --sign -s --noconfirm'||status=$?
  fi
	if [ $status != 13 ]; then
		exit 1
	fi
	cd ..
done

cp */*.pkg.tar.* ./
gpg --list-keys
repo-add --sign ./$repo_owner-lomiri.db.tar.gz ./*.pkg.tar.xz

for i in *.db *.files; do
cp --remove-destination $(readlink $i) $i
done
