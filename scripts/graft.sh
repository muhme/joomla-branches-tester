#!/bin/bash -e
#
# graft.sh - Place Joomla package onto development branch
#   graft.sh 51 ~/Downloads/Joomla_5.0.0-alpha1-Alpha-Update_Package.tar.bz2
#   graft.sh 51 pgsql ~/Downloads/Joomla_5.1.2-Stable-Full_Package.zip
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

TMP=/tmp/$(basename $0).$$
trap 'rm -rf $TMP' 0

source scripts/helper.sh

versions=$(getVersions)

if [ $# -lt 1 ]; then
  error "Needs one argument with version number from $versions"
  exit 1
fi

if isValidVersion "$1" "$versions"; then
  version="$1"
  shift # version number is eaten
else
  error "Version number argument have to be from $versions"
  exit 1
fi

# Defauls to use MariaDB with MySQLi database driver, but different one can be given
database_variant="mariadbi"
if [ $# -eq 2 ]; then
  if isValidVariant "$1"; then
    database_variant=($1)
    shift # argument is eaten as database variant
  else
    error "'$1' is not a valid selection for database and database driver, use one of ${JBT_DB_VARIANTS[@]}"
    exit 1
  fi
fi

if [ $# -ne 1 ]; then
  error "Missing Joomla package argument, e.g. Joomla_5.1.2-Stable-Full_Package.zip"
  exit 1
fi
# Convert relative path to absolute path if necessary, as we need to do change the directory. 
if [[ "$1" != /* ]]; then
    # It's a relative path
    package="$(pwd)/$FILE_PATH"
else
  package="$1"
fi
if [ ! -f "$package" ]; then
    error "Given '${package}' isn't a file"
    exit 1
fi

if [ ! -f "branch_${version}/cypress.config.dist.mjs" ]; then
  error "Missing file branch_${version}/cypress.config.dist.mjs, use create.sh first"
  exit 1
fi
if [ ! -d "branch_${version}/tests/System" ]; then
  error "Missing directory branch_${version}/tests/System, use create.sh first"
  exit 1
fi
if [ ! -d "branch_${version}/node_modules" ]; then
  error "Missing directory branch_${version}/node_modules use create.sh first"
  exit 1
fi

# On Windows WSL with Ubuntu, some files and directories may have root or www-data as their owner.
# As a result, retry any file system operation with sudo if the first attempt fails.
# And suppress stderr on the first attempt to avoid unnecessary error messages.

log "Create new directory branch_${version} with cypress.config.dist.mjs, tests/System and node_modules"
mv "branch_${version}" "branch_${version}-TMP" 2>/dev/null|| sudo mv "branch_${version}" "branch_${version}-TMP"
mkdir -p "branch_${version}/tests" 2>/dev/null || sudo mkdir -p "branch_${version}/tests"
( cd "branch_${version}-TMP"; \
  mv cypress.config.dist.mjs node_modules "../branch_${version}" 2>/dev/null || \
     sudo mv cypress.config.dist.mjs node_modules "../branch_${version}"; \
  mv tests/System "../branch_${version}/tests" 2>/dev/null || \
     sudo mv tests/System "../branch_${version}/tests" )
rm -rf "branch_${version}-TMP" 2>/dev/null || sudo rm -rf "branch_${version}-TMP"

log "Extrating package file ${package}"
cd "branch_${version}"
case "$package" in
  *.zip)
    unzip "$package" -d . 2>/dev/null || sudo unzip "$package" -d .
    ;;
  *.tar.zst)
    tar --use-compress-program=unzstd -xvf "$package" -C . 2>/dev/null || sudo tar --use-compress-program=unzstd -xvf "$package" -C . 
    ;;
  *.tar.gz|*.tar.bz2)
    tar -xvf "$package" -C . 2>/dev/null || sudo tar -xvf "$package" -C .
    ;;
  *)
    error "Unsupported file type, use .zip, .tar.gz, .tar.bz2 or .tar.zst"
    exit 1
    ;;
esac
cd ..

# Joomla container needs to be restarted to have the new folder
log "Restart containers"
docker restart "jbt_${version}"
docker restart "jbt_cypress"

log "Change root ownership to www-data"
# Following error seen on macOS, we ignore it as it does not matter, these files are 444
# chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
docker exec -it "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

# For stable releases the Joomla Web Installer stops with different 'We detected development mode' Congratulations!
# screen and you have to click in either 'Open Site' or 'Open Administrator' or all URLS ends in Web Installer.
#   public const DEV_STATUS = 'Development';
#   public const DEV_STATUS = 'Stable';

version_file="branch_${version}/libraries/src/Version.php"
if grep -q "public const DEV_STATUS = 'Stable';" "$version_file"; then
    log "Stable version detected, DEV_STATUS Development temporarily set"
    cp "$version_file" "${version_file}.orig" 2>/dev/null || sudo cp "$version_file" "${version_file}.orig"
    sed "s/public const DEV_STATUS = 'Stable';/public const DEV_STATUS = 'Development';/" "$version_file.orig" > ${TMP}
    cp ${TMP} "${version_file}" 2>/dev/null || sudo cp ${TMP} "${version_file}"
fi

# Configure and install Joomla with desired database variant
scripts/database.sh "${version}" "$database_variant"

if [ -f "${version_file}.orig" ]; then
  log "Change DEV_STATUS back to Stable"
  # The -f force option is needed to prevent interactive prompt for overwriting files.
  mv -f "${version_file}.orig" "${version_file}" 2>/dev/null || sudo mv "${version_file}.orig" "${version_file}"
fi

package_file=$(basename $package)
joomla_version=$(getJoomlaVersion branch_${version})
log "Grafting the package ${package_file} with Joomla ${joomla_version} onto branch_${version} is completed."
