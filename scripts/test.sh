#!/bin/bash
#
# test.sh - test cypress spec over on one or all branches, e.g.
#   scripts/test.sh
#   scripts/test.sh 44
#   scripts/test.sh 51 tests/System/integration/site/components/com_contact/Categories.cy.js
#   scripts/test.sh tests/System/integration/site/components/com_contact/Categories.cy.js
#   ELECTRON_ENABLE_LOGGING=1 scripts/test.sh
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' versionsToTest=($(sort <<<"${versions}")); unset IFS # map to array

if isValidVersion "$1" "$versions"; then
  versionsToTest=($1)
  shift # 1st arg is eaten as the version number
fi

# Pass through the environment variable to show 'console.log()' messages
eel1=""
if [ "$ELECTRON_ENABLE_LOGGING" == "1" ]; then
  eel1="ELECTRON_ENABLE_LOGGING=1"
fi

# Running all or having one test specification?
if [ $# -eq 0 ] ; then
  spec=""
else
  spec="--spec $1"
fi

failed=0
successful=0
for version in "${versionsToTest[@]}"
do
echo "VERSION $version"
  branch=$(branchName "${version}")
  log "Testing ${branch} ${spec}"
  docker exec -it jbt_cypress sh -c "cd /branch_${version} && ${eel1} cypress run ${spec}"
  if [ $? -eq 0 ] ; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToTest[@]} with ${successful} successful ${spec}"
else
  error "Completed ${versionsToTest[@]} with ${failed} failed and ${successful} successful ${spec}"
fi
