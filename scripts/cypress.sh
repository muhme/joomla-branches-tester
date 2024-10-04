#!/bin/bash
#
# cypress.sh - Running Cypress GUI for one branch, either from a Docker container or using locally installed Cypress.
#   scripts/cypress 51
#   scripts/cypress 51 local
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/cypress'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    cypress – Running Cypress GUI for one branch, either from a Docker container or using locally installed Cypress.
              The mandatory Joomla version argument must be one of the following: ${versions}.
              The optional 'local' argument runs Cypress directly on the Docker host (default is to run from the Docker container).

              $(random_quote)
    "
}

versions=$(getVersions)

local=false
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    version="$1"
    shift # Argument is eaten as the version number.
  elif [ $1 = "local" ]; then
    local=true
    shift # Argument is eaten to run Cypress directly on the Docker host.
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

# Use of SMTP port 7325 for the smtp-tester, as port 7125 is occupied by the mapping for the Cypress container.
if $local; then
  cd "branch_${version}"
  # Install the Cypress version used in this branch, if needed
  log "Installing Cypress if needed"

  # If it fails, try again with sudo, but specify the user's cache directory and chown afterwards.
  npm install cypress 2>/dev/null || \
    sudo bash -c "CYPRESS_CACHE_FOLDER=~$USER/.cache/Cypress npm install cypress && chown -R $USER ~$USER/.cache/Cypress"
  # Install Cypress binary.
  npx cypress install 2>/dev/null || \
    sudo bash -c "CYPRESS_CACHE_FOLDER=~$USER/.cache/Cypress npx cypress install && chown -R $USER ~$USER/.cache/Cypress"

  log "Open locally installed Cypress GUI for version ${version}"
  npx cypress open --e2e --project . --config-file cypress.config.local.mjs
  # By the way, the same way it is possible to run Cypress headless from Docker host.
else
  log "Open jbt_cypress container Cypress GUI for version ${version}"
  # Open Cypress e.g. on Windows WSL2 Docker container.
  docker exec jbt_cypress bash -c "cd \"/jbt/branch_${version}\" && DISPLAY=:0 cypress open --env smtp_port=7325 --e2e --project ."
fi
