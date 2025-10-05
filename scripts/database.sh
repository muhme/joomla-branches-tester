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
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
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
#   db_prefix: 'ajbt44_', # use of 'a' as initial letter for sorting before bak_-tables
#   db_host: 'jbt-pg',
#   db_port: '',
#   baseUrl: 'http://host.docker.internal:7044',
#   db_password: 'root',
#   smtp_host: 'host.docker.internal',
#   smtp_port: '7025',
#   instance: 44,
#   installationPath: '/jbt/joomla-44',
#
# Using database host and default port Docker-inside as performance issues are seen in using host.docker.internal
# Inserting line '/* eslint-disable */' as with 'cypress.config.local.js' we hava a not ignored file name.
#
function configureCypressConfig {
  local from="${1}" to="${2}" instance="${3}" baseurl="${4}" dbtype="${5}" dbhost="${6}" dbport="${7}" 
  local smtphost="${8}" smtpport="${9}"

  docker exec "jbt-${instance}" bash -c "echo '/* eslint-disable */' | cat - '${from}' | sed \
    -e \"s|db_type: .*|db_type: '${dbtype}',|\" \
    -e \"s|db_name: .*|db_name: 'test_joomla_${instance}',|\" \
    -e \"s|db_prefix: .*|db_prefix: 'ajbt${instance}_',|\" \
    -e \"s|db_host: .*|db_host: '${dbhost}',|\" \
    -e \"s|db_port: .*|db_port: '${dbport}',|\" \
    -e \"s|baseUrl: .*|baseUrl: '${baseurl}',|\" \
    -e \"s|db_password: .*|db_password: 'root',|\" \
    -e \"s|smtp_host: .*|smtp_host: '${smtphost}',|\" \
    -e \"s|smtp_port: .*|smtp_port: '${smtpport}',|\" \
    -e \"s|instance: .*|instance: '${instance}',|\" \
    -e \"s|installationPath: .*|installationPath: '/jbt/joomla-${instance}',|\" > '${to}'"
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

for instance in "${instancesToChange[@]}"; do

  docker exec "jbt-${instance}" bash -c "mkdir -p '/jbt/installation/joomla-${instance}' && \
                                         rm -f '/jbt/joomla-${instance}/configuration.php'"

  log "jbt-${instance} – Configure Cypress for variant ${dbvariant} (driver '${dbtype}' host '${dbhost}')"
  log "jbt-${instance} – Create 'installation/joomla-${instance}/cypress.config[.local].js' files"

  # Cypress configs for JBT installation environment
  configureCypressConfig "/jbt/configs/cypress.config.js" \
                         "/jbt/installation/joomla-${instance}/cypress.config.js" \
                         "${instance}" \
                         "http://host.docker.internal:7$(printf "%03d" "${instance}")/" \
                         "${dbtype}" \
                         "${dbhost}" \
                         "" \
                         "host.docker.internal" \
                         "7025"
  configureCypressConfig "/jbt/configs/cypress.config.js" \
                         "/jbt/installation/joomla-${instance}/cypress.config.local.js" \
                         "${instance}" \
                         "http://localhost:7$(printf "%03d" "${instance}")/" \
                         "${dbtype}" \
                         "host.docker.internal" \
                         "${dbport}" \
                         "localhost" \
                         "7325"

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

  # Joomla installation directory if missing – restore it
  restoreInstallationFolder "${instance}"

  # With PHP 8.5 and many deprecation messages, the Cypress-based installation of Joomla sometimes fails.
  # Let's just try it three times.
  count=0
  while (( count < 3 )); do
    count=$((count + 1))
    log "jbt-${instance} – Cypress-based Joomla installation ($count attempt)"
    if docker exec jbt-cypress sh -c "cd /jbt/installation && \
        CYPRESS_CACHE_FOLDER=/jbt/cypress-cache \
        DISPLAY=jbt-novnc:0 \
        ELECTRON_ENABLE_LOGGING=1 \
        CYPRESS_specPattern='/jbt/installation/installJoomla.cy.js' \
        npx cypress run --headed \
                        --config-file '/jbt/installation/joomla-${instance}/cypress.config.js'"; then

      break
    else
      if (( count >= 3 )); then
        error "jbt-${instance} – Cypress-based Joomla installation failed $count times."
        exit 1
      fi
    fi
  done

  # Set 'tEstValue' as secret etc.
  adjustJoomlaConfigurationForJBT "${instance}"

  if (( instance != 310 && instance >= 41 )); then
    log "jbt-${instance} – Disable B/C plugin(s)"
    if ! docker exec jbt-cypress sh -c "cd /jbt/installation && \
          CYPRESS_CACHE_FOLDER=/jbt/cypress-cache \
          DISPLAY=jbt-novnc:0 \
          ELECTRON_ENABLE_LOGGING=1 \
          CYPRESS_specPattern='/jbt/installation/disableBC.cy.js' \
          npx cypress run --headed \
                          --config-file '/jbt/installation/joomla-${instance}/cypress.config.js'"; then
      error "jbt-${instance} – Ignoring failed step 'Disable B/C plugin'."
    fi
  fi

  # Enable Joomla logging
  log "jbt-${instance} – Configure Joomla with 'Debug System' and 'Log Almost Everything' (but not 'Log Deprecated API')"
  docker exec "jbt-${instance}" bash -c "cd /var/www/html && sed \
    -e 's/\$debug = .*/\$debug = true;/' \
    -e 's/\$log_everything = .*/\$log_everything = 1;/' \
    configuration.php > configuration.php.tmp && \
    mv configuration.php.tmp configuration.php"
  # Not configure Joomla 'Log Deprecated API' as running System Tests 5.4 in Sep 2025 with 574 tests results
  # in over one million log entries respective nearly 300 MB log file size.
  # log "jbt-${instance} – Configure Joomla with 'Debug System', 'Log Almost Everything' and 'Log Deprecated API'"
  # -e 's/\$log_deprecated = .*/\$log_deprecated = 1;/' \

  log "jbt-${instance} – Changing ownership to www-data for all files and directories (in background)"
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true &' &

  log "jbt-${instance} – Joomla has been new installed using the '${dbvariant}' database variant."
done
