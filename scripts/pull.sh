#!/bin/bash
#
# pull.sh - Running git pull and git status on one or all branches, e.g.
#   scripts/pull.sh
#   scripts/pull.sh 52
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

if [ $# -gt 1 ] ; then
  error "Only one argument with version number is possible"
  exit 1
fi

versions=$(getVersions)
IFS=' ' versionsToPull=($(sort <<<"${versions}")); unset IFS # map to array

if [ $# -eq 1 ] ; then
  if isValidVersion "$1" "$versions"; then
    versionsToPull=($1)
    shift # 1st arg is eaten as the version number
  else
    error "Version number argument have to be from ${versions}"
    exit 1
  fi
fi

failed=0
successful=0
for version in "${versionsToPull[@]}"
do
  branch=$(branchName "${version}")
  log "Running git pull on ${branch}"
  docker exec -it "jbt_${version}" sh -c "git config --global --add safe.directory /var/www/html && git pull"
  if [ $? -eq 0 ] ; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
  log "Showing git status on ${branch}"
  docker exec -it "jbt_${version}" sh -c "git status"
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToTest[@]} with ${successful} successful ${spec}"
else
  error "Completed ${versionsToTest[@]} with ${failed} failed and ${successful} successful ${spec}"
fi
