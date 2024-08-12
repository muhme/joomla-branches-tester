#!/bin/bash -e
#
# mysql.sh - Change Database to MySQL for one or all Joomla container.
#   scripts/mysql.sh
#   scripts/mysql.sh 51
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

ME=`basename $0`
TMP="/tmp/$ME.TMP.$$"
trap 'rm -rf $TMP' 0

source scripts/helper.sh

versions=("${VERSIONS[@]}")

if [ $# -gt 1 ] ; then
  error "Only one argument with version number is possible"
  exit 1
fi

if [ $# -eq 1 ] ; then
  if isValidVersion "$1"; then
    versions=($1)
  else
    error "Version number argument have to be from ${VERSIONS[@]}"
    exit 1
  fi
fi

for version in "${versions[@]}"; do

  # Handle .js or .mjs from PR https://github.com/joomla/joomla-cms/pull/43676 – [4.4] Move the Cypress Tests to ESM
  if [ -f "branch_${version}/cypress.config.dist.js" ]; then
    extension="js"
  elif [ -f "branch_${version}/cypress.config.dist.mjs" ]; then
    extension="mjs"
  else
    error "No 'cypress.config.dist.*js' file found, please have a look" >&2
    exit 1
  fi

  log "jbt_${version} – Create cypress.config.${extension} for MySQL"
  # adopt e.g.:
  #   >     db_name: 'test_joomla_44'
  #   >     db_prefix: 'jos44_',
  #   >     db_host: 'jbt_mysql',
  #   >     db_port: '',
  #   >     baseUrl: 'http://host.docker.internal:7044',
  #   >     db_password: 'root',
  #   >     smtp_host: 'host.docker.internal',
  #   >     smtp_port: '7025',

  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/db_name: .*/db_name: 'test_joomla_${version}',/\" \
    -e \"s/db_prefix: .*/db_prefix: 'jos${version}_',/\" \
    -e \"s/db_host: .*/db_host: 'jbt_mysql',/\" \
    -e \"s/db_port: .*/db_port: '',/\" \
    -e \"s/baseUrl: .*/baseUrl: 'http:\/\/host.docker.internal:70${version}\/',/\" \
    -e \"s/db_password: .*/db_password: 'root',/\" \
    -e \"s/smtp_host: .*/smtp_host: 'host.docker.internal',/\" \
    -e \"s/smtp_port: .*/smtp_port: '7025',/\" \
    cypress.config.dist.${extension} > cypress.config.${extension}"

  # 'Hack' until PR with setting db_port is supported - overwrite with setting db_port in joomla-cypress and System Tests
  # (Only used later if we run Cypress GUI)
  append="/db_host: Cypress.env('db_host'),/a\      db_port: Cypress.env('db_port'), // muhme, 9 August 2024 'hack' as long as waiting for PR"
  sed "${append}" "branch_${version}/tests/System/integration/install/Installation.cy.js" > $TMP
  cp $TMP "branch_${version}/tests/System/integration/install/Installation.cy.js"
  cp scripts/Joomla.js "branch_${version}/node_modules/joomla-cypress/src/Joomla.js"

  # Using Install Joomla from System Tests
  log "jbt_${version} – Cypress based Joomla installation"
  docker exec -it jbt_cypress sh -c "cd /branch_${version} && cypress run --spec tests/System/integration/install/Installation.cy.js"
  
  log "jbt_${version} – MySQL based Joomla is installed"
  echo ""

done
