#!/bin/bash
#
# clean.sh - Stopping and removing JBT Docker containers, associated Docker networks and volumes.
#            Also deletes files and directories created by JBT.
#            Works offline and for earlier JBT version created directories and containers.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/clean'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    clean – Stops and removes all JBT Docker containers, associated Docker networks, and Docker volumes.
            Also deletes JBT directories, such as 'run' and all 'joomla-*' directories.
            The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

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
if [[ ! -f "docker-compose.yml" ]]; then
  log "Missing 'docker-compose.yml' file, create one with all branch versions to remove Joomla Branches Tester overall"
  createDockerComposeFile "$(getAllUsedBranches)" "php8.2" "IPv4"
fi

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

# Clean up joomla directories if existing
for dir in joomla-*; do
  if [ -d "$dir" ]; then
    log "Removing directory '${dir}'"
    # sudo is needed on Windows WSL Ubuntu
    rm -rf "$dir" 2>/dev/null || sudo rm -rf "$dir"
  fi
done

# Branch directories with underscore, before JBT 2.0.5?
for dir in branch_*; do
  if [ -d "$dir" ]; then
    log "Removing old directory '${dir}'"
    rm -rf "$dir" 2>/dev/null || sudo rm -rf "$dir"
  fi
done

# Delete all log files, except the actual one :)
if [ -d "logs" ]; then
  log "Removing all files in the 'logs' directory, except the most recent one"
  # remove log files with underscores before 2.0.12
  rm -f logs/*_*.txt 2>/dev/null || sudo rm -f logs/*_*.txt
  find logs -type f | sort -r | tail -n +2 >"${JBT_TMP_FILE}"
  xargs -r rm -f -- <"${JBT_TMP_FILE}" 2>/dev/null || sudo bash -c "xargs -r rm -f -- <\"${JBT_TMP_FILE}\""
fi

# Checking Cypress global binary cache for macOS and Linux
for dir in "${HOME}/Library/Caches/Cypress" "${HOME}/.cache/Cypress"; do
  # $dir exists and contains at least one directory
  if [[ -d "${dir}" && "$(find "$dir" -mindepth 1 -type d | head -n 1)" ]]; then
    log "Cache for local Cypress runs has been found in the '${dir}' directory with the following sizes (in MB):"
    du -ms "${dir}"/* || true
    log "You can delete all outdated versions from your local Cypress cache using the list above"
  fi
done

# Deleting files listed in .gitignore, even though it's not required, to ensure cleanup.
for file in "docker-compose.yml" "docker-compose.new" "installation/package.json" "installation/package-lock.json"; do
  if [ -f "${file}" ]; then
    log "Deleting file '${file}' to ensure complete cleanup"
    rm -f "${file}" 2>/dev/null || sudo bash -c "rm -f \"${file}\""
  fi
done

# Deleting directories in .gitignore, even though it's not required, to ensure cleanup.
for directory in ".vscode" "run" "cypress-cache" installation/*; do
  if [ -d "${directory}" ]; then
    log "Deleting directory '${directory}' to ensure complete cleanup"
    rm -rf "${directory}" 2>/dev/null || sudo bash -c "rm -rf \"${directory}\""
  fi
done
