#!/bin/bash -e
#
# graft.sh - Place Joomla package onto development branch.
#            Just like in plant grafting, where a scion is joined to a rootstock.
#   scripts/graft.sh 52 ~/Downloads/Joomla_5.2.0-alpha4-dev-Development-Full_Package.zip
#   scripts/graft.sh /tmp/Joomla_5.1.2-Stable-Full_Package.zip 51 pgsql
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/info.sh'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    graft.sh – Place Joomla package onto development branch.
               Just like in plant grafting, where a scion is joined to a rootstock.
               The mandatory Joomla version argument must be one of the following: ${versions}.
               The Joomla package file argument (e.g. 'Joomla_5.1.2-Stable-Full_Package.zip') is mandatory.
               Optional database variant can be one of: ${JBT_DB_VARIANTS[@]} (default is mariadbi).

               $(random_quote)
    "
}

versions=$(getVersions)

database_variant="mariadbi"
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    version="$1"
    shift # Argument is eaten as the version number.
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

if [ -z "${version}" ]; then
  help
  error "Please provide a Joomla version number from the following: ${versions}."
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

if [ ! -f "branch_${version}/cypress.config.dist.mjs" ]; then
  error "Missing file 'branch_${version}/cypress.config.dist.mjs'. Please use 'scripts/create.sh' first."
  exit 1
fi
if [ ! -d "branch_${version}/tests/System" ]; then
  error "Missing directory 'branch_${version}/tests/System'. Please use 'scripts/create.sh' first."
  exit 1
fi
if [ ! -d "branch_${version}/node_modules" ]; then
  error "Missing directory 'branch_${version}/node_modules'. Please use 'scripts/create.sh' first."
  exit 1
fi

# On Windows WSL with Ubuntu, some files and directories may have root or www-data as their owner.
# As a result, retry any file system operation with sudo if the first attempt fails.
# And suppress stderr on the first attempt to avoid unnecessary error messages.

log "Creating new directory 'branch_${version}' and copy three files and two directories."
mv "branch_${version}" "branch_${version}-TMP" 2>/dev/null|| sudo mv "branch_${version}" "branch_${version}-TMP"
mkdir -p "branch_${version}/tests" 2>/dev/null || sudo mkdir -p "branch_${version}/tests"
( cd "branch_${version}-TMP"; \
  mv cypress.config.dist.mjs package.json package-lock.json node_modules "../branch_${version}" 2>/dev/null || \
     sudo mv cypress.config.dist.mjs node_modules "../branch_${version}"; \
  mv tests/System "../branch_${version}/tests" 2>/dev/null || \
     sudo mv tests/System "../branch_${version}/tests" )
rm -rf "branch_${version}-TMP" 2>/dev/null || sudo rm -rf "branch_${version}-TMP"

log "Extracting package file '${package}'."
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
    error "Unsupported file type. Please use one of the following: .zip, .tar.gz, .tar.bz2, or .tar.zst."
    exit 1
    ;;
esac
cd ..

# Joomla container needs to be restarted to access the new folder.
log "Restarting Docker containers."
docker restart "jbt_${version}"
docker restart "jbt_cypress"

log "Changing ownership to www-data for all files and directories."
# Following error seen on macOS, we ignore it as it does not matter, these files are all 444.
# chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
docker exec "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

# For stable releases the Joomla Web Installer stops with different 'We detected development mode' Congratulations!
# screen and you have to click in either 'Open Site' or 'Open Administrator' or all URLs end in Web Installer.
#   public const DEV_STATUS = 'Development';
#   public const DEV_STATUS = 'Stable';
if grep -q "public const DEV_STATUS = 'Stable';" "branch_${version}/libraries/src/Version.php"; then
  log "Stable Joomla version detected."
  # Is the patch already there?
  PATCHED="branch_${version}/node_modules/joomla-cypress/src/joomla.js"
  if grep -q "button.complete-installation" "${PATCHED}"; then
    log "jbt_${version} – Patch https://github.com/joomla-projects/joomla-cypress/pull/35 has already been applied."
  else
    log "jbt_${version} – Applying changes as in https://github.com/joomla-projects/joomla-cypress/pull/35."
    while IFS= read -r line; do
      if [[ "$line" == *"--Install Joomla--"* ]]; then
        # Insert the patch
        echo "// muhme, 25 August 2024 'hack' as long as waiting for PR https://github.com/joomla-projects/joomla-cypress/pull/35"
        echo "// is merged, and new joomla-cypress release is build and used in all active Joomla branches"
        echo ""
        echo "// In case of Joomla Stable release the Joomla Web Installer needs one more click to complete the installation"
        echo "cy.get('button.complete-installation')"
        echo '    .then($button => {'
        echo "    // Check if the button exists"
        echo '  if ($button.length > 0) {'
        echo "    // If the button exists, click it"
        echo '    cy.wrap($button).first().click()'
        echo "  }"
        echo "})"
      fi
      # Always print the original line.
      echo "$line"
    done < "${PATCHED}" > "${TMP}"
    # If copying the file has failed, start a second attempt with sudo.
    cp "${TMP}" "${PATCHED}" || sudo cp "${TMP}" "${PATCHED}"
  fi
fi

# Configure and install Joomla with desired database variant.
scripts/database.sh "${version}" "$database_variant"

package_file=$(basename $package)
joomla_version=$(getJoomlaVersion branch_${version})
log "Grafting the package '${package_file}' with Joomla ${joomla_version} onto branch_${version} is complete."
