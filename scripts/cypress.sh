#!/bin/bash
#
# cypress.sh - Running Cypress GUI for one branch from Docker container or with locally installed Cypress
#   scripts/cypress.sh 51
#   scripts/cypress.sh 51 local
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)

if [ $# -lt 1 ] ; then
  error "Needs one argument with version number from $versions"
  exit 1
fi

if isValidVersion "$1" "$versions"; then
  version="$1"
else
  error "Version number argument have to be from $versions"
  exit 1
fi

if [ "$2" = "local" ]; then
  log "Open local installed Cypress GUI for ${version}"
  cd "branch_${version}"
  npx cypress open --env smtp_port=7026 --e2e --project .
  # By the way, the same way it is possible to run Cypress headless from Docker host
else
  log "Open jbt_cypress container Cypress GUI for ${version}"
  docker exec -it jbt_cypress bash -c "cd \"/branch_${version}\" && cypress open --env smtp_port=7026 --e2e --project ."
fi
