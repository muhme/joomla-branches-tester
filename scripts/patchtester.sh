#!/bin/bash
#
# patchtester.sh - install patchtester on one or all branches, e.g.
#   scripts/patchtester.sh 44 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester.sh ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versionsToInstall=("${VERSIONS[@]}")

if isValidVersion "$1"; then
   versionsToInstall=($1)
   shift # 1st arg is eaten as the version number
fi

# Check if the given token looks like a GitHub personal access token
if [[ $1 != ghp_* ]]; then
  error "Error: Argument with GitHub personal access token 'ghp_*' is missing."
  exit 1
fi

failed=0
successful=0
for version in "${versionsToInstall[@]}"
do
  branch=$(branchName "${version}")
  log "Install Joomla Patch Tester in ${branch} ${spec}"
  docker exec -it jbt_cypress sh -c "cd /branch_${version} && cypress run --env token=$1 --config specPattern=/scripts/patchtester.cy.js"
  if [ $? -eq 0 ] ; then
    ((successful++))
  else
    ((failed++))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToInstall[@]} with ${successful} successful ${spec}"
else
  error "Completed ${versionsToInstall[@]} with ${failed} failed and ${successful} successful ${spec}"
fi
