#!/bin/bash -e
#
# graft.sh - Places a Joomla package onto an existing instance.
#            Just like in plant grafting, where a scion is joined to a rootstock.
#   scripts/graft 52 ~/Downloads/Joomla_5.2.0-alpha4-dev-Development-Full_Package.zip
#   scripts/graft /tmp/Joomla_5.1.2-Stable-Full_Package.zip 51 pgsql
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/graft'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    graft – Places a Joomla package onto an existing instance, similar to plant grafting, where a scion joins a rootstock.
            The mandatory Joomla instance must be one of installed: ${allInstalledInstances[*]}.
            The Joomla package file (e.g. 'Joomla_5.1.2-Stable-Full_Package.zip') is also mandatory.
            Optional database variant can be one of: ${JBT_DB_VARIANTS[*]} (default is mariadbi).
            The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

            $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in instance numbers
allInstalledInstances=($(getAllInstalledInstances))

database_variant="mariadbi"
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instance="$1"
    shift # Argument is eaten as the instance number.
  elif isValidVariant "$1"; then
    database_variant="$1"
    shift # Argument is eaten as database variant.
  elif [[ "$1" =~ \.(zip|tar|tar\.zst|tar\.gz|tar\.bz2)$ ]]; then
    package="$1"
    shift # Argument is eaten as package file.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${instance}" ]; then
  help
  error "Please provide a Joomla instance from the following: ${allInstalledInstances[*]}."
  exit 1
fi

if [ -z "${package}" ]; then
  help
  error "Please provide a Joomla package argument, e.g. local file 'Joomla_5.1.2-Stable-Full_Package.zip'."
  exit 1
fi

# Convert relative path to absolute path if necessary, as we need to change the working directory. 
if [[ "$package" != /* ]]; then
    # It's a relative path.
    package="$(pwd)/$package"
fi
if [ ! -f "$package" ]; then
    error "Given '${package}' package is not a file. Please check."
    exit 1
fi

# On Windows WSL with Ubuntu, some files and directories may have root or www-data as their owner.
# As a result, retry any file system operation with sudo if the first attempt fails.
# And suppress stderr on the first attempt to avoid unnecessary error messages.

log "Creating new directory 'joomla-${instance}' and copy three files and two directories (if existing)"
mv "joomla-${instance}" "joomla-${instance}-TMP" 2>/dev/null|| sudo mv "joomla-${instance}" "joomla-${instance}-TMP"
mkdir -p "joomla-${instance}/tests" 2>/dev/null || (sudo mkdir -p "joomla-${instance}/tests" && sudo chmod 777 "joomla-${instance}")
for entry in "cypress.config.dist.js" "cypress.config.dist.mjs" "package.json" "package-lock.json" "node_modules" "tests/System"; do
  from="joomla-${instance}-TMP/${entry}"
  to="joomla-${instance}/${entry}"
  if [[ -f "${from}" || -d "${from}" ]]; then
    mv "${from}" "${to}" 2>/dev/null || sudo mv "${from}" "${to}"
  fi
done
rm -rf "joomla-${instance}-TMP" 2>/dev/null || sudo rm -rf "joomla-${instance}-TMP"

log "Extracting package file '${package}'"
cd "joomla-${instance}"
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
    error "Unsupported file type. Please use one of the following: .zip, .tar.gz, .tar.bz2, or .tar.zst."
    exit 1
    ;;
esac
cd ..

# Joomla container needs to be restarted to access the new folder.
log "Restarting Docker containers"
docker restart "jbt-${instance}" "jbt-cypress"

log "Changing ownership to www-data for all files and directories"
# Following error seen on macOS, we ignore it as it does not matter, these files are all 444.
# chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

# For stable releases the Joomla Web Installer stops with different 'We detected development mode' Congratulations!
# screen and you have to click in either 'Open Site' or 'Open Administrator' or all URLs end in Web Installer.
# The joomla-cypress-35 patch fixes this issue and is included in the default patch list.

# Configure and install Joomla with desired database variant.
scripts/database.sh "${instance}" "$database_variant"

package_file=$(basename "${package}")
joomla_version=$(getJoomlaVersion "joomla-${instance}")
log "Grafting the package '${package_file}' with Joomla ${joomla_version} onto 'joomla-${instance}' is complete"
