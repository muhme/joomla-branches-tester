#!/bin/bash
#
# clean.sh - Stopping and removing JBT Docker containers, associated Docker networks and volumes.
#            Also deletes dirctory 'run' and all 'branch_*' directories.
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
    clean.sh – Stops and removes all JBT Docker containers, associated Docker networks, and volumes.
               Also deletes dirctory 'run' and all 'branch_*' directories.

               $(random_quote)
    "
}

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# Delete all docker containters. The PHP version and network do not affect the deletion process.
log "Create 'docker-compose.yml' file with all branch versions to remove Joomla Branches Tester overall."
createDockerComposeFile "${versions}" "php8.2" "IPv4"

log 'Stopping and removing JBT Docker containers, associated Docker networks and volumes.'
docker compose down -v

# Old containers existing?
echo '*** Remove following Docker containers'
docker ps -a --format '{{.Names}}' | grep "^jbt_" | while read container; do
  log "Removing non docker-compose container '${container}'."
  docker rm -f "${container}"
done

# Clean up branch directories if existing
for version in "${allVersions[@]}"; do
  if [ -d "branch_${version}" ]; then
    log "Removing directory 'branch_${version}'."
    # sudo is needed on Windows WSL Ubuntu
    rm -rf "branch_${version}" >/dev/null 2>&1 || sudo rm -rf "branch_${version}"
  fi
done

# Branch directories from old version numbers?
for dir in branch_*; do
  if [ -d "$dir" ]; then
    log "Removing non-existing version directory '${dir}'."
    rm -rf "$dir" 2>&1 || sudo rm -rf "$dir"
  fi
done

# Database sockets must be deleted; otherwise, they will be mapped to the new instances.
if [ -d "run" ]; then
  log "Removing directory 'run'."
  rm -rf run 2>/dev/null || sudo rm -rf run
fi

# Cypress and web server containers shared Cypress binaries
if [ -d "cypress-cache" ]; then
  log "Removing directory 'cypress-cache'."
  rm -rf cypress-cache 2>/dev/null || sudo rm -rf cypress-cache
fi

# Checking Cypress global binary cache for macOS and Linux
for dir in "${HOME}/Library/Caches/Cypress" "${HOME}/.cache/Cypress"; do
  if [ -d "${dir}" ]; then
    log "Cache for local Cypress runs has been found in the '${dir}' directory with the following sizes (in MB):"
    du -ms ${dir}/* || true
    log "You may delete outdated versions from the local Cypress cache."
  fi
done
