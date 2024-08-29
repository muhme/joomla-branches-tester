#!/bin/bash
#
# patchtester.sh - Install Joomla Patch Tester on all, one or muliple Docker containers, e.g.
#   scripts/patchtester.sh ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester.sh 44 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester.sh 52 53 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

versionsToInstall=()
while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
  elif [[ $1 = ghp_* ]]; then
    token="$1"
    shift # Argument is eaten as GitHub token.
  else
    log "Please provide a valid GitHub personal access token starting with 'ghp_'."
    log "Optional Joomla version can be one or more of the following: ${allVersions[@]} (default is all)."
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# If no version was given, use all.
if [ ${#versionsToInstall[@]} -eq 0 ]; then
  versionsToInstall=(${allVersions[@]})
fi

# Check if the given token looks like a GitHub personal access token
if [ -z "${token}" ]; then
  if [[ "${JBT_GITHUB_TOKEN}" =~ ghp_* ]]; then
    token="${JBT_GITHUB_TOKEN}"
    log "Using GitHub token from the environment variable 'JBT_GITHUB_TOKEN'."
  else
    error "Please provide a valid GitHub personal access token starting with 'ghp_'."
    exit 1
  fi
fi

failed=0
successful=0
for version in "${versionsToInstall[@]}"
do
  branch=$(branchName "${version}")
  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi
  log "jbt_${version} – Installing Joomla Patch Tester."
  docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && cypress run --env token=${token} --config specPattern=/jbt/scripts/patchtester.cy.js"
  if [ $? -eq 0 ] ; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToInstall[@]} with ${successful} successful."
else
  error "Completed ${versionsToInstall[@]} with ${failed} failed and ${successful} successful."
fi
