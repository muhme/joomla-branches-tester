#!/bin/bash
#
# clean.sh - delete all jbt_* Docker containers and the network joomla-branches-tester_default.
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

# Delete all docker containters
createDockerComposeFile "${allVersions[*]}" 

log 'Stop and remove Joomla Branches Tester Docker containers and network'
docker compose down

# Clean up branch directories if existing
for version in "${allVersions[@]}"; do
  if [ -d "branch_${version}" ]; then
    log "Removing directory branch_${version}"
    # sudo is needed on Windows WSL Ubuntu
    rm -rf "branch_${version}" >/dev/null 2>&1 || sudo rm -rf "branch_${version}"
  fi
done
