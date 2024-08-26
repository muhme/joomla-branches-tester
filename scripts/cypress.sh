#!/bin/bash
#
# cypress.sh - Running Cypress GUI for one branch from Docker container or with locally installed Cypress
#   scripts/cypress.sh 51
#   scripts/cypress.sh 51 local
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)

if [ $# -lt 1 ]; then
  error "Please give one argument with version number from ${versions}."
  exit 1
fi

if isValidVersion "$1" "$versions"; then
  version="$1"
else
  error "Please use a version number from ${versions}."
  exit 1
fi

if [ $# -eq 2 ] && [ "$2" != "local" ]; then
  error "Please use 'local' as second argument."
  exit 1
fi

# Use of SMTP port 7325 for the smtp-tester, as port 7125 is occupied by the mapping for the Cypress container.
if [ "$2" = "local" ]; then
  cd "branch_${version}"
  # Install smtp-tester, if needed (after )
  if [ ! -d node_modules/smtp-tester ]; then
     log "Installing smtp-tester."
     npm install smtp-tester --save-dev
  fi
  # Install the Cypress version used in this branch, if needed
  log "Installing Cypress if needed."
  npm install cypress --save-dev
  # it was needed on Ubuntu to run again with npx
  npx cypress install 
  log "Open locally installed Cypress GUI for version ${version}."
  npx cypress open --e2e --project . --config-file cypress.config.local.mjs
  # By the way, the same way it is possible to run Cypress headless from Docker host
else
  log "Open jbt_cypress container Cypress GUI for version ${version}."
  docker exec -it jbt_cypress bash -c "cd \"/jbt/branch_${version}\" && cypress open --env smtp_port=7325 --e2e --project ."
fi
