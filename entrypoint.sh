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
# need it for telepathy-farstream
echo '[ironrobin-lomiri]' >> /etc/pacman.conf
echo 'Server = https://github.com/ironrobin/lomiri-packages/releases/download/packages' >> /etc/pacman.conf

sudo pacman-key --recv-keys 6ED02751500A833A
sudo pacman-key --lsign-key 6ED02751500A833A

sudo pacman -Sy
sudo pacman -S base-devel --noconfirm --needed

pkgs=(
  accountsservice-ubuntu
  qt5-pim-git
  telepathy-farstream
  telepathy-qt-git
  lomiri-history-service-git
  properties-cpp
  dbus-test-runner
  click-git
  cmake-extras-git
  qdjango-git
  libqtdbustest-git
  libusermetrics-git
  lomiri-api-git
  lomiri-app-launch-git
  lomiri-url-dispatcher-git
  lomiri-notifications-git
  lomiri-telephony-service-git
  humanity-icon-theme
  suru-icon-theme-git
  lomiri-ui-toolkit-git
  buteo-syncfw-qml-git
)

for i in "${pkgs[@]}" ; do
	status=13
	git submodule update --init $i
	cd $i

	for i in $(sudo -u builduser makepkg --packagelist); do
		package=$(basename $i)
		wget https://github.com/$repo_owner/$repo_name/releases/download/packages/$package \
			&& echo "Warning: $package already built, did you forget to bump the pkgver and/or pkgrel? It will not be rebuilt."
	done
	sudo -u builduser bash -c 'export MAKEFLAGS=-j$(nproc) && makepkg --sign -s --noconfirm'||status=$?

	# Package already built is fine.
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
