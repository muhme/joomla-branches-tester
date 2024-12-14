#!/bin/bash
#
# cypress.sh - Running Cypress GUI, either from a Docker container or using locally installed Cypress.
#   scripts/cypress 51                  # Joomla System Tests on Windows WSL 2 Ubuntu
#   scripts/cypress 51 local            # Joomla System Tests on macOS and Ubuntu native
#   scripts/cypress 52 joomla-cypress   # joomla-cypress tests
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
              The optional 'local' argument runs Cypress on the Docker host (default: Docker container).
              The optional 'joomla-cypress' argument tests 'joomla-cypress' (default: Joomla System Tests).
              The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

# shellcheck disable=SC2207 # There are no spaces in instance numbers
allInstalledInstances=($(getAllInstalledInstances))

local="" # defaults to false
joomla_cypress=false
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instance="$1"
    shift # Argument is eaten as the instance number.
  elif [ "$1" = "local" ]; then
    local=".local" # set true and use it as part for config file path
    shift # Argument is eaten to run Cypress directly on the Docker host.
  elif [ "$1" = "joomla-cypress" ]; then
    joomla_cypress=true
    shift # Argument is eaten to run Cypress for joomla-cypress
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

if ${joomla_cypress}; then
  cypress_dir="installation/joomla-cypress"
  # joomla-cypress' installJoomlaMultilingualSite() test deletes installation directory – restore it
  restoreInstallationFolder "${instance}"
else
  cypress_dir="joomla-${instance}"
  # With https://github.com/joomla/joomla-cms/pull/44253 Joomla command line client usage has been added
  # to the System Tests. Hopefully, this is only temporary and can be replaced to reduce complexity and dependency.
  # Joomla command line client inside Docker container needs to wrote 'configuration.php' file.
  log "Chmod 644 'joomla-${instance}/configuration.php' for cli/joomla.php"
  chmod 644 "joomla-${instance}/configuration.php" 2>/dev/null ||
    sudo chmod 644 "joomla-${instance}/configuration.php"
fi

# Determine Cypress config file
# e.g. joomla-52/cypress.config.local.mjs or installation/joomla-52/cypress.config.local.js
if ${joomla_cypress}; then
  prefix="../joomla-${instance}/"
else
  prefix=""
fi
if [ -f "${cypress_dir}/${prefix}cypress.config${local}.mjs" ]; then
  config_file="${prefix}cypress.config${local}.mjs"
elif [ -f "${cypress_dir}/${prefix}cypress.config${local}.js" ]; then
  config_file="${prefix}cypress.config${local}.js"
else
  error "There is no file '${prefix}cypress.config${local}.[m]js'."
  exit 1
fi

# Use of SMTP port 7325 for the smtp-tester, as port 7125 is occupied by the mapping for the Cypress container.
if [ -n "${local}" ]; then
  # Don't use 'cypress-cache' for local running Cypress GUI, as e.g. macOS reinstalls with Cypress.app and
  # Linux is later missing Cypress. Users' Cypress default cache is used.
  export CYPRESS_CACHE_FOLDER="${HOME}/.cache/Cypress"
  cd "${cypress_dir}" || {
    error "OOPS - Unable to move into the '${cypress_dir}' directory, giving up."
    exit 1
  }
  # Install the Cypress version used in this Joomla instance or installation/joomla-cypress, if needed
  log "Installing required Cypress binary version locally (if needed)"
  npx cypress install 2>/dev/null ||
    sudo bash -c "CYPRESS_CACHE_FOLDER=$CYPRESS_CACHE_FOLDER npx cypress install && chown -R $USER $CYPRESS_CACHE_FOLDER"

  # For installExtensionFromFolder() in joomla-cypress/cypress/extensions.cy.js needed
  # to find 'mod_hello_world' folder. And we can not use 'fixturesFolder' as this is
  # needed for installExtensionFromFileUpload() with default 'cypress/fixtures'.
  export CYPRESS_SERVER_UPLOAD_FOLDER='/jbt/installation/joomla-cypress/cypress/fixtures/mod_hello_world'

  # For joomla-cypress you can set CYPRESS_SKIP_INSTALL_LANGUAGES=1
  # to skip installLanguage() and installJoomlaMultilingual() tests. Default here to run the test.
  export CYPRESS_SKIP_INSTALL_LANGUAGES="${CYPRESS_SKIP_INSTALL_LANGUAGES:-0}"

  log "jbt-${instance} – Open locally installed Cypress GUI"
  npx cypress open --e2e --project . --config-file "${config_file}"
  # By the way, the same way it is possible to run Cypress headless from Docker host.
else
  log "jbt-${instance} – Open jbt-cypress container Cypress GUI"
  # Open Cypress e.g. on Windows WSL 2 Docker container.
  docker exec jbt-cypress bash -c "cd '/jbt/${cypress_dir}' && \
                                   CYPRESS_CACHE_FOLDER=/jbt/cypress-cache \
                                   CYPRESS_SKIP_INSTALL_LANGUAGES='${CYPRESS_SKIP_INSTALL_LANGUAGES}' \
                                   DISPLAY=:0 \
                                   npx cypress open --env smtp_port=7325 --e2e --project . --config-file '${config_file}'"
fi
