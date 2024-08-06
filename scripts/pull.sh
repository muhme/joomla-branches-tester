#!/bin/bash
#
# pull.sh - git pull on one or all branches, e.g.
#   scripts/pull.sh
#   scripts/pull.sh 52
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh

versionsToTest=("${VERSIONS[@]}")

if [ $# -gt 1 ] ; then
  error "Only one argument with version number is possible"
  exit 1
fi

if [ $# -eq 1 ] ; then
  if isValidVersion "$1"; then
    versionsToTest=($1)
    shift # 1st arg is eaten as the version number
  else
    error "Version number argument have to be from ${VERSIONS[@]}"
    exit 1
  fi
fi

failed=0
successful=0
for version in "${versionsToTest[@]}"
do
  branch=$(branchName "${version}")
  log "Running git pull on ${branch}"
  docker exec -it "jst_${version}" sh -c "git config --global --add safe.directory /var/www/html && git pull"
  if [ $? -eq 0 ] ; then
    ((successful++))
  else
    ((failed++))
  fi
  log "Showing git status on ${branch}"
  docker exec -it "jst_${version}" sh -c "git status"
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${versionsToTest[@]} with ${successful} successful ${spec}"
else
  error "Completed ${versionsToTest[@]} with ${failed} failed and ${successful} successful ${spec}"
fi
