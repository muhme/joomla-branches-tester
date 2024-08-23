#!/bin/bash
#
# patchtester.sh - install patchtester on one or all branches, e.g.
#   scripts/patchtester.sh 44 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester.sh ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' versionsToInstall=($(sort <<<"${versions}")); unset IFS # map to array

if isValidVersion "$1" "$versions"; then
  versionsToInstall=($1)
  shift # 1st arg is eaten as the version number
fi

# Check if the given token looks like a GitHub personal access token
if [[ $1 = ghp_* ]]; then
  token="$1"
elif [[ "${JBT_GITHUB_TOKEN}" = ghp_* ]]; then
  token="${JBT_GITHUB_TOKEN}"
  log "Use GitHub token from the environment variable JBT_GITHUB_TOKEN"
else
  error "Error: Argument with GitHub personal access token 'ghp_*' is missing."
  exit 1
fi

failed=0
successful=0
for version in "${versionsToInstall[@]}"
do
  branch=$(branchName "${version}")
  log "Install Joomla Patch Tester in ${branch}"
  docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && cypress run --env token=${token} --config specPattern=/jbt/scripts/patchtester.cy.js"
  if [ $? -eq 0 ] ; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToInstall[@]} with ${successful} successful"
else
  error "Completed ${versionsToInstall[@]} with ${failed} failed and ${successful} successful"
fi
