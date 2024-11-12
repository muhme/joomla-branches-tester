#!/bin/bash
#
# cypress.sh - Running Cypress GUI, either from a Docker container or using locally installed Cypress.
#   scripts/cypress 51         # macOS and Ubuntu native
#   scripts/cypress 51 local   # Windows WSL2 Ubuntu
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
    cypress – Runs the Cypress GUI, either from Docker container or locally installed Cypress.
              The mandatory Joomla instance must be one of installed: ${allInstalledInstances[*]}.
              The optional 'local' argument runs Cypress on the Docker host (default is the Docker container).
              The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

              $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in instance numbers
allInstalledInstances=($(getAllInstalledInstances))

local=false
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instance="$1"
    shift # Argument is eaten as the instance number.
  elif [ "$1" = "local" ]; then
    local=true
    shift # Argument is eaten to run Cypress directly on the Docker host.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${instance}" ]; then
  help
  error "Please provide a Joomla instance number from the following: ${allInstalledInstances[*]}."
  exit 1
fi

# Use of SMTP port 7325 for the smtp-tester, as port 7125 is occupied by the mapping for the Cypress container.
if $local; then
  cd "joomla-${instance}" || {
    error "OOPS - Unable to move into the 'joomla-${instance}' directory, giving up."
    exit 1
  }
  # Install the Cypress version used in this Joomla instance, if needed
  log "Installing Cypress if needed"

  # If it fails, try again with sudo, but specify the user's cache directory and chown afterwards.
  npm install cypress 2>/dev/null || \
    sudo bash -c "CYPRESS_CACHE_FOLDER=~$USER/.cache/Cypress npm install cypress && chown -R $USER ~$USER/.cache/Cypress"
  # Install Cypress binary.
  npx cypress install 2>/dev/null || \
    sudo bash -c "CYPRESS_CACHE_FOLDER=~$USER/.cache/Cypress npx cypress install && chown -R $USER ~$USER/.cache/Cypress"

  if [ -f "cypress.config.local.mjs" ]; then
    config_file="cypress.config.local.mjs"
  elif [ -f "cypress.config.local.js" ]; then
    config_file="cypress.config.local.js"
  else
    error "There is no file 'joomla-${instance}/cypress.config.local.*js'."
    exit 1
  fi
  log "jbt-${instance} – Open locally installed Cypress GUI"
  npx cypress open --e2e --project . --config-file "${config_file}"
  # By the way, the same way it is possible to run Cypress headless from Docker host.
else
  log "jbt-${instance} – Open jbt-cypress container Cypress GUI"
  # Open Cypress e.g. on Windows WSL2 Docker container.
  docker exec jbt-cypress bash -c "cd \"/jbt/joomla-${instance}\" && DISPLAY=:0 cypress open --env smtp_port=7325 --e2e --project ."
fi
