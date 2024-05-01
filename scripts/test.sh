#!/bin/bash
#
# test.sh - delete all jst_* docker containers
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh

if [ $# -eq 1 ] ; then
  spec="$1"
else
  error "Missing test argument, e.g. tests/System/integration/site/components/com_privacy/Request.cy.js"
  exit 1
fi

failed=0
successful=0
for version in "${VERSIONS[@]}"
do
  log "Testing ${version} ${spec}"
  docker exec -it jst_cypress sh -c "cd /branch_${version} && cypress run --spec ${spec}"
  if [ $? -eq 0 ] ; then
    ((successful++))
  else
    ((failed++))
  fi
done

log "Completed ${failed} failed and ${successful} successful tests"
