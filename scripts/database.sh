#!/bin/bash -e
#
# database.sh - Change the database and database driver for all, one or multiple Joomla containers.
#   scripts/database mysqli socket
#   scripts/database 44 mariadb
#   scripts/database 53 60 pgsql
#
# Creates three Cypress configuration files:
#   installation/joomla-${instance}/cypress.config.js
#   joomla-${instance}/cypress.config.[m]js
#   joomla-${instance}/cypress.config.local.[m]js
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/database'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

# Configure cypress.config.*js
#
# adopt e.g.:
#   db_type: 'PostgreSQL (PDO)',
#   db_name: 'test_joomla_44'
#   db_prefix: 'jos44_',
#   db_host: 'jbt-pg',
#   db_port: '',
#   baseUrl: 'http://host.docker.internal:7044',
#   db_password: 'root',
#   smtp_host: 'host.docker.internal',
#   smtp_port: '7025',
#
# Using database host and default port Docker-inside as performance issues are seen in using host.docker.internal
#
function configureCypressConfig {
  local from="$1" to="$2" instance="$3" baseurl="$4" dbtype="$5" dbhost="$6" dbport="$7" smtphost="$8" smtpport="$9"

  docker exec "jbt-${instance}" bash -c "sed \
    -e \"s|instance: .*|instance: '${instance}',|\" \
    -e \"s|db_type: .*|db_type: '${dbtype}',|\" \
    -e \"s|db_name: .*|db_name: 'test_joomla_${instance}',|\" \
    -e \"s|db_prefix: .*|db_prefix: 'jos${instance}_',|\" \
    -e \"s|db_host: .*|db_host: '${dbhost}',|\" \
    -e \"s|db_port: .*|db_port: '${dbport}',|\" \
    -e \"s|baseUrl: .*|baseUrl: '${baseurl}',|\" \
    -e \"s|db_password: .*|db_password: 'root',|\" \
    -e \"s|smtp_host: .*|smtp_host: '${smtphost}',|\" \
    -e \"s|smtp_port: .*|smtp_port: '${smtpport}',|\" \
    '${from}' > '${to}'"
}

function help {
    echo "
    database – Changes the database and driver for all, one or multiple Joomla web server containers.
               The mandatory database variant must be one of: ${JBT_DB_VARIANTS[*]}.
               The optional 'socket' argument configures database access via Unix socket (default is TCP host).
               Optional Joomla instances can include one or more of the installed: ${allInstalledInstances[*]} (default is all).
               The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

socket=false
instancesToChange=()
# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToChange+=("$1")
    shift # Argument is eaten as one version number.
  elif [ "$1" = "socket" ]; then
    socket=true
    if [ -n "${dbvariant}" ] ; then
      # Database variant was already given, overwrite with Unix socket
      dbhost=$(dbSocketForVariant "${dbvariant}")
      dbport=""
    fi
    shift # Argument is eaten as use database vwith socket.
  elif isValidVariant "$1"; then
    dbvariant="$1"
    dbtype=$(dbTypeForVariant "${dbvariant}")
    if $socket; then
      # Use Unix socket
      dbhost=$(dbSocketForVariant "${dbvariant}")
      dbport=""
    else
      # Use TCP host
      dbhost=$(dbHostForVariant "${dbvariant}")
      dbport=$(dbPortForVariant "${dbvariant}")
    fi
    shift # Argument is eaten as database variant.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "$dbvariant" ] ; then
  help
  error "Mandatory database variant is missing. Please use one of: ${JBT_DB_VARIANTS[*]}."
  exit 1
fi

# If no version was given, use all.
if [ ${#instancesToChange[@]} -eq 0 ]; then
  instancesToChange=("${allInstalledInstances[@]}")
fi

# JBT Cypress Installation Environment

if [ ! -d "installation/node_modules" ]; then
  log "Performing a clean install of 'cypress' in 'installation/node_modules' directory"
  docker exec "jbt-cypress" bash -c "cd /jbt/installation && npm ci"
  log "Adding 'joomla-cypress' module as a Git shallow clone of the main branch"
  docker exec "jbt-cypress" bash -c "cd /jbt/installation/node_modules && \
                                     git clone --depth 1 https://github.com/joomla-projects/joomla-cypress"
   # Seen on Ubuntu, 13.10.0 was installed, but 12.13.2 needed for the Joomla instance
  log "Install Cypress (if needed)"
  # docker exec jbt-cypress sh -c "cd /jbt/installation && npx cypress install"
  # Seen on macOS, 13.13.3 was installed, npx cypress install did not install needed 13.13.0
  # docker exec jbt-cypress sh -c "cd /jbt/installation && npm run cypress:install"
  # Seen on macOS, "The cypress npm package is installed, but the Cypress binary is missing."
  docker exec jbt-cypress sh -c "cd /jbt/installation && cypress install"
fi

for instance in "${instancesToChange[@]}"; do

  docker exec "jbt-${instance}" bash -c "mkdir -p '/jbt/installation/joomla-${instance}' && \
                                         cp /jbt/installation/installJoomla.cy.js '/jbt/installation/joomla-${instance}' && \
                                         rm -f '/jbt/joomla-${instance}/configuration.php'"

  log "jbt-${instance} – Configure Cypress for variant ${dbvariant} (driver '${dbtype}' host '${dbhost}')"
  log "jbt-${instance} – Create 'installation/joomla-${instance}/cypress.config.js' file"

  # Cypress config for JBT installation environment
  configureCypressConfig "/jbt/configs/cypress.config.js" \
                         "/jbt/installation/joomla-${instance}/cypress.config.js" \
                         "${instance}" \
                         "http://host.docker.internal:7$(printf "%03d" "${instance}")/" \
                         "${dbtype}" \
                         "${dbhost}" \
                         "" \
                         "host.docker.internal" \
                         "7025"

  # Cypress config files for Joomla instance (if needed)
  if [[ -f "joomla-${instance}/cypress.config.dist.js" || -f "joomla-${instance}/cypress.config.dist.mjs" ]]; then
    if [ -f "joomla-${instance}/cypress.config.dist.mjs" ]; then
      extension="mjs"
    else
      extension="js"
    fi
    log "jbt-${instance} – Create 'joomla-${instance}/cypress.config[.local].${extension}' files"
    configureCypressConfig "cypress.config.dist.${extension}" \
                           "cypress.config.${extension}" \
                           "${instance}" \
                           "http://host.docker.internal:7$(printf "%03d" "${instance}")/" \
                           "${dbtype}" \
                           "${dbhost}" \
                           "" \
                           "host.docker.internal" \
                           "7125"
    # Create second Cypress config file for running local
    # Using host.docker.internal to have it reachable from outside for Cypress and inside web server container
    configureCypressConfig "cypress.config.dist.${extension}" \
                           "cypress.config.local.${extension}" \
                           "${instance}" \
                           "http://localhost:7$(printf "%03d" "${instance}")/" \
                           "${dbtype}" \
                           "host.docker.internal" \
                           "${dbport}" \
                           "localhost" \
                           "7325"
  fi

  # Since the database will be new, we clean up autoload classes cache file and
  # all com_patchtester directories to prevent the next installation to be fail.
  # Again in Docker container as www-data user.
  docker exec "jbt-${instance}" bash -c "
    cd /var/www/html
    rm -rf administrator/components/com_patchtester api/components/com_patchtester
    rm -rf media/com_patchtester administrator/cache/autoload_psr4.php"

  if [ ! -d "joomla-${instance}/installation" ]; then
    log "jbt-${instance} – Missing 'installation' directory, doing Git checkout"
    docker exec "jbt-${instance}" bash -c "git checkout installation"
  fi

  log "jbt-${instance} – Cypress-based Joomla installation"
  docker exec jbt-cypress sh -c "cd '/jbt/installation/joomla-${instance}' && \
       DISPLAY=jbt-novnc:0 \
       CYPRESS_specPattern='/jbt/installation/installJoomla.cy.js' \
       cypress run --headed"

  # Adopt 'configuration.php' as in 'tests/System/integration/install/Installation.cy.js'
  docker exec "jbt-${instance}" bash -c "sed -i \
    -e \"s|\(public .secret =\).*|\1 'tEstValue';|\" \
    -e \"s|\(public .mailonline =\).*|\1 true;|\" \
    -e \"s|\(public .mailer =\).*|\1 'smtp';|\" \
    -e \"s|\(public .smtphost =\).*|\1 'host.docker.internal';|\" \
    -e \"s|\(public .smtpport =\).*|\1 7025;|\" \
    configuration.php"

  if (( instance != 310 && instance >= 41 )); then
    log "jbt-${instance} – Disable B/C plugin(s)"
    if ! docker exec jbt-cypress sh -c "cd /jbt/installation/joomla-${instance} && \
          DISPLAY=jbt-novnc:0 \
          CYPRESS_specPattern='/jbt/installation/disableBC.cy.js' \
          cypress run --headed"; then
      error "jbt-${instance} – Ignoring failed step 'Disable B/C plugin'."
    fi
  fi

  # Not configure Joomla logging as we deprecated and System Tests will fail
  #
  # Enable Joomla logging
  # log "jbt-${instance} – Configure Joomla with 'Debug System', 'Log Almost Everything' and 'Log Deprecated API'"
  # docker exec "jbt-${instance}" bash -c "cd /var/www/html && sed \
  #   -e 's/\$debug = .*/\$debug = true;/' \
  #   -e 's/\$log_everything = .*/\$log_everything = 1;/' \
  #   -e 's/\$log_deprecated = .*/\$log_deprecated = 1;/' \
  #   configuration.php > configuration.php.tmp && \
  #   mv configuration.php.tmp configuration.php"

  log "jbt-${instance} – Changing ownership to www-data for all files and directories (in background)"
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true &' &

  log "jbt-${instance} – Joomla has been new installed using the '${dbvariant}' database variant."
done
