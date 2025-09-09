
REPONAME="ironrobin-lomiri"
PKGNAME="telepathy-farstream"
#VERSION="0.5.0-5"
VERSION=""

# check the ${PKGNAME}/PKGBUILD for the pkgver and pkgrel

# Extract version from PKGBUILD
PKGVERLINE=$(grep -E '^pkgver=' $PKGNAME/PKGBUILD)
PKGVER="${PKGVERLINE#*=}"
PKGRELLINE=$(grep -E '^pkgrel=' $PKGNAME/PKGBUILD)
PKGREL="${PKGRELLINE#*=}"
echo "Version: $PKGVER"
VERSION="${PKGVER}-${PKGREL}"

# Check if package of version exists in the repo using pacman -Si
# if pacman -Si $PKGNAME &> /dev/null; then
#     # Get the version of the package in the repo
#     REPO_VERSION=$(pacman -Si $PKGNAME | grep Version | awk '{print $3}')
#     if [ "$REPO_VERSION" == "$VERSION" ]; then
#         echo "Package $PKGNAME of version $VERSION already exists in the $REPONAME repo."
#         exit 0
#     else
#         echo "Package $PKGNAME exists but with a different version ($REPO_VERSION) in the $REPONAME repo."
#         exit 1
#     fi
# else
#     echo "Package $PKGNAME does not exist in the $REPONAME repo."
#     exit 1
# fi


if pacman -Si $PKGNAME &> /dev/null; then
  REPO_VERSION=$(pacman -Si $PKGNAME | grep Version | awk '{print $3}')
  echo "REPO_VERSION: $REPO_VERSION"
  echo "VERSION: $VERSION"
  echo "PKGNAME: $PKGNAME"
  if (( $(vercmp "$VERSION" "$REPO_VERSION") < 0 )); then
    echo "Package $PKGNAME of version $VERSION is older than the version ($REPO_VERSION) in the $REPONAME repo. Not building."
  elif [ "$REPO_VERSION" == "$VERSION" ]; then
    echo "Package $PKGNAME of version $VERSION already exists in the $REPONAME repo. Not building."
  else
    echo "Package $PKGNAME exists but with a different version ($REPO_VERSION) in the $REPONAME repo. Building new version $VERSION."
    #sudo -u builduser bash -c 'export MAKEFLAGS=-j$(nproc) && makepkg --sign -s --noconfirm'||status=$?
  fi
else
   echo "Package $PKGNAME does not exist in the $REPONAME repo. Adding it."
  #sudo -u builduser bash -c 'export MAKEFLAGS=-j$(nproc) && makepkg --sign -s --noconfirm'||status=$?
fi

