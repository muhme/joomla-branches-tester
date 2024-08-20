#!/bin/bash -e
#
# database.sh - Change Database and database driver for one or all Joomla container.
#   scripts/database.sh mysqli
#   scripts/database.sh 51 pgsql
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' versionsToChange=($(sort <<<"${versions}")); unset IFS # map to array

if isValidVersion "$1" "$versions"; then
  versionsToChange=($1)
  shift # 1st arg is eaten as the version number
fi

if [ $# -lt 1 ] ; then
  error "Desired selection of database and driver is missing, use one of ${JBT_DB_VARIANTS[@]}"
  exit 1
fi

if isValidVariant "$1"; then
  variant=($1)
  dbtype=$(dbTypeForVariant "$variant")
  dbhost=$(dbHostForVariant "$variant")
  shift # argument is eaten
else
  error "'$1' is not a valid selection for database and database driver, use one of ${JBT_DB_VARIANTS[@]}"
  exit 1
fi

for version in "${versionsToChange[@]}"; do

  log "jbt_${version} – Create cypress.config.mjs for variant ${variant} (driver '${dbtype}' host '${dbhost}')"

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

  # 'Hack' until PR with setting db_port is supported - overwrite with setting db_port in joomla-cypress and System Tests
  # (Only used later if we run Cypress GUI)
  # Don't use sed inplace editing as not supported by macOS, do it in Docker container as owner is www-data
  docker exec -it "jbt_${version}" bash -c "
    cd /var/www/html/tests/System/integration/install
    sed '/db_host: Cypress.env('\"'\"'db_host'\"'\"'),/a\\      db_port: Cypress.env('\"'\"'db_port'\"'\"'), // muhme, 9 August 2024 \"hack\" as long as waiting for PR' Installation.cy.js > Installation.cy.js.tmp
    mv Installation.cy.js.tmp Installation.cy.js"
  docker cp scripts/Joomla.js "jbt_${version}:/var/www/html/node_modules/joomla-cypress/src/Joomla.js"

  # Since the database will be new, we clean up autoload classes cache file and
  # all com_patchtester directories to prevent the next installation to be fail.
  # Again in Docker container as www-data user.
  docker exec -it "jbt_${version}" bash -c "
    cd /var/www/html
    rm -rf administrator/components/com_patchtester api/components/com_patchtester
    rm -rf media/com_patchtester administrator/cache/autoload_psr4.php"

  # Using Install Joomla from System Tests
  log "jbt_${version} – Cypress based Joomla installation"
  docker exec -it jbt_cypress sh -c "cd /branch_${version} && cypress run --spec tests/System/integration/install/Installation.cy.js"

  # Cypress is using own SMTP port to read and reset mails by smtp-tester
  log "jbt_${version} – Set Cypress SMTP port to 7125"
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/smtp_port: .*/smtp_port: '7125',/\" \
    cypress.config.mjs > cypress.config.mjs.tmp && \
    mv cypress.config.mjs.tmp cypress.config.mjs"

  log "jbt_${version} – ${variant} based Joomla is installed"
  echo ""

done
