#!/bin/bash
#
# cypress.sh - Running Cypress GUI for one branch
#   scripts/cypress.sh 51
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

if [ $# -ne 1 ] ; then
  error "Needs one argument with version number, e.g. 51"
  exit 1
fi

if isValidVersion "$1"; then
  version="$1"
else
  error "Version number argument have to be from ${VERSIONS[@]}"
  exit 1
fi

log "Open Cypress GUI for ${version}"
cd "branch_${version}"
npx cypress open --env smtp_port=7026

# By the way, the same way it is possible to run Cypress headless from Docker host
