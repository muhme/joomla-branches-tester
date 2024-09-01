#!/bin/bash -e
#
# database.sh - Change the database and database driver for all, one or multiple Joomla containers.
#   scripts/database.sh mysqli
#   scripts/database.sh 44 mariadb
#   scripts/database.sh 53 60 pgsql
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

TMP=/tmp/$(basename $0).$$
trap 'rm -rf $TMP' 0

source scripts/helper.sh

versionsToChange=()
versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToChange+=("$1")
    shift # Argument is eaten as version number.
  elif isValidVariant "$1"; then
    dbvariant="$1"
    dbtype=$(dbTypeForVariant "$dbvariant")
    dbhost=$(dbHostForVariant "$dbvariant")
    dbport=$(dbPortForVariant "$dbvariant")
    shift # Argument is eaten as database variant.
  else
    log "Mandatory database variant can be one of: ${JBT_DB_VARIANTS[@]}."
    log "Optional Joomla version can be one or more of the following: ${versions} (default is all, e.g. '52 53')."
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "$dbvariant" ] ; then
  error "Mandatory database variant is missing. Please use one of: ${JBT_DB_VARIANTS[@]}."
  exit 1
fi

# If no version was given, use all.
if [ ${#versionsToChange[@]} -eq 0 ]; then
  versionsToChange=(${allVersions[@]})
fi

for version in "${versionsToChange[@]}"; do

  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi

  log "jbt_${version} – Create 'cypress.config.mjs' file for variant ${dbvariant} (driver '${dbtype}' host '${dbhost}')."

  # adopt e.g.:
  #   db_type: 'PostgreSQL (PDO)',
  #   db_name: 'test_joomla_44'
  #   db_prefix: 'jos44_',
  #   db_host: 'jbt_pd',
  #   db_port: '',
  #   baseUrl: 'http://host.docker.internal:7044',
  #   db_password: 'root',
  #   smtp_host: 'host.docker.internal',
  #   smtp_port: '7025',
  #
  # Using database host and default port Docker-inside as performance issues are seen in using host.docker.internal
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/db_type: .*/db_type: '${dbtype}',/\" \
    -e \"s/db_name: .*/db_name: 'test_joomla_${version}',/\" \
    -e \"s/db_prefix: .*/db_prefix: 'jos${version}_',/\" \
    -e \"s/db_host: .*/db_host: '${dbhost}',/\" \
    -e \"s/db_port: .*/db_port: '',/\" \
    -e \"s/baseUrl: .*/baseUrl: 'http:\/\/host.docker.internal:70${version}\/',/\" \
    -e \"s/db_password: .*/db_password: 'root',/\" \
    -e \"s/smtp_host: .*/smtp_host: 'host.docker.internal',/\" \
    -e \"s/smtp_port: .*/smtp_port: '7025',/\" \
    cypress.config.dist.mjs > cypress.config.mjs"

  # Create second Cypress config file for running local
  # Using host.docker.internal to have it reachable from outside for Cypress and inside web server container
  log "jbt_${version} – Create additional 'cypress.config.local.mjs' file with using localhost and database port ${dbport}."
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/db_host: .*/db_host: 'host.docker.internal',/\" \
    -e \"s/db_port: .*/db_port: '$dbport',/\" \
    -e \"s/baseUrl: .*/baseUrl: 'http:\/\/localhost:70${version}\/',/\" \
    -e \"s/smtp_host: .*/smtp_host: 'localhost',/\" \
    -e \"s/smtp_port: .*/smtp_port: '7325',/\" \
    cypress.config.mjs > cypress.config.local.mjs"

  # Joomla System Tests 'Hack' until PR https://github.com/joomla/joomla-cms/pull/43968
  # '[cypress] Add db_port in Installation.cy.js' is merged in all! active Joomla branches.
  # - Only used in Cypress GUI in spec Installation.cy.js
  # - Don't use sed inplace editing as not supported by macOS, do it in Docker container as owner is www-data

  if grep -q "db_port" "branch_${version}/tests/System/integration/install/Installation.cy.js"; then
    log "jbt_${version} – Patch https://github.com/joomla/joomla-cms/pull/43968 has already been applied."
  else
    log "jbt_${version} – Applying changes as in https://github.com/joomla/joomla-cms/pull/43968."
    docker exec -it "jbt_${version}" bash -c "
      cd /var/www/html/tests/System/integration/install
      sed '/db_host: Cypress.env('\"'\"'db_host'\"'\"'),/a\\      db_port: Cypress.env('\"'\"'db_port'\"'\"'), // muhme, 9 August 2024 \"hack\" waiting for PR https://github.com/joomla/joomla-cms/pull/43968' Installation.cy.js > Installation.cy.js.tmp
      mv Installation.cy.js.tmp Installation.cy.js"
  fi

  # joomla-cypress 'Hack' until PR https://github.com/joomla-projects/joomla-cypress/pull/33
  # 'Install Joomla with non-standard db_port' is merged, new joomla-cypress release is build and used in all active Joomla branches

  # Line to be replaced
  SEARCH_LINE="cy.get('#jform_db_host').clear().type(config.db_host)"

  # Replacement
  PATCH=$(cat <<'EOF'
// muhme, 9 August 2024 'hack' as long as waiting for PR https://github.com/joomla-projects/joomla-cypress/pull/33 is merged, and new joomla-cypress release is build and used in all active Joomla branches
let connection = config.db_host
if (config.db_port && config.db_port.trim() !== '') {
  connection += `:${config.db_port.trim()}`;
}
cy.get('#jform_db_host').clear().type(connection)
EOF
)

  # Check if the patch is already there
  PATCHED="branch_${version}/node_modules/joomla-cypress/src/joomla.js"
  if grep -q "${SEARCH_LINE}" "${PATCHED}"; then
    log "jbt_${version} – Applying changes as in https://github.com/joomla-projects/joomla-cypress/pull/33."
    while IFS= read -r line; do
      if [[ "$line" == *"$SEARCH_LINE"* ]]; then
        # Insert the patch
        echo "$PATCH"
      else
        # Print the original line
        echo "$line"
      fi
    done < "${PATCHED}" > "${TMP}"
    # if copying the file has failed, start a second attempt with sudo
    cp "${TMP}" "${PATCHED}" 2>/dev/null || sudo cp "${TMP}" "${PATCHED}"
  else
    log "jbt_${version} – Patch https://github.com/joomla-projects/joomla-cypress/pull/33 has already been applied."
  fi

  # Since the database will be new, we clean up autoload classes cache file and
  # all com_patchtester directories to prevent the next installation to be fail.
  # Again in Docker container as www-data user.
  docker exec -it "jbt_${version}" bash -c "
    cd /var/www/html
    rm -rf administrator/components/com_patchtester api/components/com_patchtester
    rm -rf media/com_patchtester administrator/cache/autoload_psr4.php"

  # Seen on Ubuntu, 13.10.0 was installed, but 12.13.2 needed for the branch
  log "jbt_${version} – Install Cypress (if needed)."
  docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && npx cypress install"

  # Using Install Joomla from System Tests
  log "jbt_${version} – Cypress-based Joomla installation."
  docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && unset DISPLAY && cypress run --spec tests/System/integration/install/Installation.cy.js"

  # Cypress is using own SMTP port to read and reset mails by smtp-tester
  log "jbt_${version} – Set the SMTP port used by Cypress to 7125."
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/smtp_port: .*/smtp_port: '7125',/\" \
    cypress.config.mjs > cypress.config.mjs.tmp && \
    mv cypress.config.mjs.tmp cypress.config.mjs"

  log "jbt_${version} – Changing ownership to www-data for all files and directories."
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec -it "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

  log "jbt_${version} – Joomla based on the $(branchName ${dbvariant}) database variant is installed."

done
