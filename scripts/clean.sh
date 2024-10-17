#!/bin/bash
#
# clean.sh - Stopping and removing JBT Docker containers, associated Docker networks and volumes.
#            Also deletes directory 'run' and all 'branch-*' directories.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/clean'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    clean – Stops and removes all JBT Docker containers, associated Docker networks, and volumes.
            Also deletes JBT directories, such as 'run' and all 'branch-*' directories.

            $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getVersions))

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

# Delete all docker containers. The PHP version and network do not affect the deletion process.
log "Create 'docker-compose.yml' file with all branch versions to remove Joomla Branches Tester overall"
createDockerComposeFile "${allVersions[*]}" "php8.2" "IPv4"

log 'Stopping and removing JBT Docker containers, associated Docker networks and volumes'
docker compose down -v

# Old containers existing?
log "Check for any other Docker containers with names starting with 'jbt-*'"
docker ps -a --format '{{.Names}}' | grep "^jbt-" | while read -r container; do
  log "Removing non docker-compose container '${container}'"
  docker rm -f "${container}"
done

# Older containers with underscore hostnames existing?
log "Check for any other Docker containers with names starting with 'jbt_*'"
docker ps -a --format '{{.Names}}' | grep "^jbt_" | while read -r container; do
  log "Removing non docker-compose container '${container}'"
  docker rm -f "${container}"
done

# Old network existing?
log "Checking for the existence of the 'jbt-network' Docker network'"
docker network ls --format '{{.Name}}' | grep "^jbt-network$" | while read -r network; do
  log "Removing non docker-compose network '${network}'"
  docker network rm "${network}"
done

# Older network with underscore existing?
log "Checking for the existence of the 'jbt_network' Docker network'"
docker network ls --format '{{.Name}}' | grep "^jbt_network$" | while read -r network; do
  log "Removing non docker-compose network '${network}'"
  docker network rm "${network}"
done

# Clean up branch directories if existing
for version in "${allVersions[@]}"; do
  if [ -d "branch-${version}" ]; then
    log "Removing directory 'branch-${version}'"
    # sudo is needed on Windows WSL Ubuntu
    rm -rf "branch-${version}" >/dev/null 2>&1 || sudo rm -rf "branch-${version}"
  fi
done

# Branch directories not in the used versions list?
for dir in branch-*; do
  if [ -d "$dir" ]; then
    log "Removing non-existing version directory '${dir}'"
    rm -rf "$dir" 2>&1 || sudo rm -rf "$dir"
  fi
done

# Branch directories with underscore, before JBT 2.0.5?
for dir in branch_*; do
  if [ -d "$dir" ]; then
    log "Removing old directory '${dir}'"
    rm -rf "$dir" 2>&1 || sudo rm -rf "$dir"
  fi
done

# Database sockets must be deleted; otherwise, they will be mapped to the new instances.
if [ -d "run" ]; then
  log "Removing 'run' directory containing Unix socket subdirectories for databases"
  rm -rf run 2>/dev/null || sudo rm -rf run
fi

# Delete all log files, except the actual one :)
if [ -d "logs" ]; then
  log "Removing all files in the 'logs' directory, except for the most recent one"
  # remove log files with underscores before 2.0.12
  rm -f logs/*_*.txt 2>/dev/null || sudo rm -f logs/*_*.txt
  find logs -type f | sort -r | tail -n +2 >"${TMP}"
  xargs -r rm -- <"${TMP}" 2>/dev/null || sudo bash -c "xargs -r rm -- <\"${TMP}\""
fi

# Cypress and web server containers shared Cypress binaries
if [ -d "cypress-cache" ]; then
  log "Removing shared Cypress binaries directory 'cypress-cache'"
  rm -rf cypress-cache 2>/dev/null || sudo rm -rf cypress-cache
fi

# Checking Cypress global binary cache for macOS and Linux
for dir in "${HOME}/Library/Caches/Cypress" "${HOME}/.cache/Cypress"; do
  if [ -d "${dir}" ]; then
    log "Cache for local Cypress runs has been found in the '${dir}' directory with the following sizes (in MB):"
    du -ms "${dir}"/* || true
    log "You can delete the oldest and outdated versions from your local Cypress cache using the list above"
  fi
done

# Deleting files listed in .gitignore, even though it's not required, to ensure cleanup.
for file in ".vscode" "docker-compose.yml"; do
  if [ -f "${file}" ]; then
    log "Deleting file '${file}' to ensure complete cleanup"
    rm "${file}"
  fi
done
