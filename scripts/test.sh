#!/bin/bash
#
# test.sh - test cypress spec over on one or all branches, e.g.
#   scripts/test.sh 51 tests/System/integration/site/components/com_contact/Categories.cy.js
#   scripts/test.sh tests/System/integration/site/components/com_contact/Categories.cy.js
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh
versionsToTest=("${VERSIONS[@]}")

if [ $# -eq 0 ] ; then
  error "Missing test argument, e.g. tests/System/integration/site/components/com_privacy/Request.cy.js"
  exit 1
fi

if isValidVersion "$1"; then
   versionsToTest=($1)
   shift # 1st arg is eaten as the version number
fi

if [ $# -eq 0 ] ; then
  error "Missing test argument, e.g. tests/System/integration/site/components/com_privacy/Request.cy.js"
  exit 1
fi

spec="$1"

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
  log "Completed ${successful} successful ${spec}"
else
  error "Completed ${failed} failed and ${successful} successful ${spec}"
fi
