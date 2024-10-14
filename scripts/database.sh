#!/bin/bash -e
#
# database.sh - Change the database and database driver for all, one or multiple Joomla containers.
#   scripts/database mysqli socket
#   scripts/database 44 mariadb
#   scripts/database 53 60 pgsql
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/database'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    database – Change the database and database driver for all, one or multiple Joomla containers.
               The mandatory database variant must be one of: ${JBT_DB_VARIANTS[*]}.
               Optional Joomla version can be one or more of the following: ${allVersions[*]} (default is all).
               Optional 'socket' for using the database with a Unix socket (default is using TCP host).

               $(random_quote)
    "
}

socket=false
versionsToChange=()
# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getVersions))

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${allVersions[*]}"; then
    versionsToChange+=("$1")
    shift # Argument is eaten as version number.
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
if [ ${#versionsToChange[@]} -eq 0 ]; then
  versionsToChange=("${allVersions[@]}")
fi

for version in "${versionsToChange[@]}"; do

  if [ ! -d "branch-${version}" ]; then
    log "jbt-${version} – There is no directory 'branch-${version}', jumped over"
    continue
  fi

  log "jbt-${version} – Create 'cypress.config.mjs' file for variant ${dbvariant} (driver '${dbtype}' host '${dbhost}')"

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
  docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
    -e \"s|db_type: .*|db_type: '${dbtype}',|\" \
    -e \"s|db_name: .*|db_name: 'test_joomla_${version}',|\" \
    -e \"s|db_prefix: .*|db_prefix: 'jos${version}_',|\" \
    -e \"s|db_host: .*|db_host: '${dbhost}',|\" \
    -e \"s|db_port: .*|db_port: '',|\" \
    -e \"s|baseUrl: .*|baseUrl: 'http:\/\/host.docker.internal:70${version}\/',|\" \
    -e \"s|db_password: .*|db_password: 'root',|\" \
    -e \"s|smtp_host: .*|smtp_host: 'host.docker.internal',|\" \
    -e \"s|smtp_port: .*|smtp_port: '7025',|\" \
    cypress.config.dist.mjs > cypress.config.mjs"

  # Create second Cypress config file for running local
  # Using host.docker.internal to have it reachable from outside for Cypress and inside web server container
  log "jbt-${version} – Create additional 'cypress.config.local.mjs' file with using localhost and database port ${dbport}"
  docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
    -e \"s|db_host: .*|db_host: 'host.docker.internal',|\" \
    -e \"s|db_port: .*|db_port: '$dbport',|\" \
    -e \"s|baseUrl: .*|baseUrl: 'http:\/\/localhost:70${version}\/',|\" \
    -e \"s|smtp_host: .*|smtp_host: 'localhost',|\" \
    -e \"s|smtp_port: .*|smtp_port: '7325',|\" \
    cypress.config.mjs > cypress.config.local.mjs"

  # Since the database will be new, we clean up autoload classes cache file and
  # all com_patchtester directories to prevent the next installation to be fail.
  # Again in Docker container as www-data user.
  docker exec "jbt-${version}" bash -c "
    cd /var/www/html
    rm -rf administrator/components/com_patchtester api/components/com_patchtester
    rm -rf media/com_patchtester administrator/cache/autoload_psr4.php"

  # Seen on Ubuntu, 13.10.0 was installed, but 12.13.2 needed for the branch
  log "jbt-${version} – Install Cypress (if needed)"
  docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && npx cypress install"
  # Seen on macOS, 13.13.3 was installed, npx cypress install did not install needed 13.13.0
  docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && npm run cypress:install"
  # Seen on macOS, "The cypress npm package is installed, but the Cypress binary is missing."
  docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && cypress install"

  # Using Install Joomla from System Tests
  log "jbt-${version} – Cypress-based Joomla installation"
  docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && \
       DISPLAY=jbt-novnc:0 cypress run --headed --spec tests/System/integration/install/Installation.cy.js"

  log "jbt-${version} – Disable B/C plugin"
  if ! docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && \
        DISPLAY=jbt-novnc:0 CYPRESS_specPattern='/jbt/scripts/disableBC.cy.js' cypress run --headed"; then
    error "jbt-${version} – Ignoring failed step 'Disable B/C plugin'."
  fi

  # Cypress is using own SMTP port to read and reset mails by smtp-tester
  log "jbt-${version} – Set the SMTP port used by Cypress to 7125"
  docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
    -e \"s/smtp_port: .*/smtp_port: '7125',/\" \
    cypress.config.mjs > cypress.config.mjs.tmp && \
    mv cypress.config.mjs.tmp cypress.config.mjs"

  # Enable Joomla logging
  log "jbt-${version} – CONFIGURE JOOMLA NOT FOR LOGGING AS WE HAVE DEPRECATED"
  # log "jbt-${version} – Configure Joomla with 'Debug System', 'Log Almost Everything' and 'Log Deprecated API'"
  # docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
  #   -e 's/\$debug = .*/\$debug = true;/' \
  #   -e 's/\$log_everything = .*/\$log_everything = 1;/' \
  #   -e 's/\$log_deprecated = .*/\$log_deprecated = 1;/' \
  #   configuration.php > configuration.php.tmp && \
  #   mv configuration.php.tmp configuration.php"

  log "jbt-${version} – Changing ownership to www-data for all files and directories"
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec "jbt-${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

  log "jbt-${version} – Joomla has been freshly installed using the '${dbvariant}' database variant."
done
