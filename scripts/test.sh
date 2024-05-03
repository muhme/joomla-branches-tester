#!/bin/bash
#
# test.sh - test cypress spec over on one or all branches, e.g.
#   scripts/test.sh
#   scripts/test.sh 44
#   scripts/test.sh 51 tests/System/integration/site/components/com_contact/Categories.cy.js
#   scripts/test.sh tests/System/integration/site/components/com_contact/Categories.cy.js
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh

# all tests (w/o installation) as taken from cypress.config.js specPattern
ALL_TESTS='tests/System/integration/administrator/**/*.cy.{js,jsx,ts,tsx},tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx},tests/System/integration/api/**/*.cy.{js,jsx,ts,tsx},tests/System/integration/plugins/**/*.cy.{js,jsx,ts,tsx}'
versionsToTest=("${VERSIONS[@]}")

if isValidVersion "$1"; then
   versionsToTest=($1)
   shift # 1st arg is eaten as the version number
fi

if [ $# -eq 0 ] ; then
  spec=${ALL_TESTS}
else
  spec="$1"
fi

failed=0
successful=0
for version in "${versionsToTest[@]}"
do
  branch=$(branchName "${version}")
  log "Testing ${branch} ${spec}"
  docker exec -it jst_cypress sh -c "cd /branch_${version} && cypress run --spec ${spec}"
  if [ $? -eq 0 ] ; then
    ((successful++))
  else
    ((failed++))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToTest[@]} with ${successful} successful ${spec}"
else
  error "Completed ${versionsToTest[@]} with ${failed} failed and ${successful} successful ${spec}"
fi
