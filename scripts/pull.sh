#!/bin/bash
#
# pull.sh - Running git pull and more on all, one or multiple branches, e.g.
#   scripts/pull.sh
#   scripts/pull.sh 51
#   scripts/pull.sh 52 53
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

function help {
    echo "
    pull.sh – Running 'git pull' on one or multiple branches.
              Running composer install if changes are detected and npm clean install if needed.
              Optional version can be one or more of the following: ${allVersions[@]} (default is all).

              `random_quote`
    "
}

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

versionsToPull=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    versionsToPull+=("$1")
    shift # Argument is eaten as one version number.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# If no version was given, use all.
if [ ${#versionsToPull[@]} -eq 0 ]; then
  versionsToPull=(${allVersions[@]})
fi

pulled=0
for version in "${versionsToPull[@]}"
do
  branch=$(branchName "${version}")
  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi
  log "jbt_${version} – Running Git fetch origin for ${branch}."
  # Prevent dubious ownership in repository
  docker exec -it "jbt_${version}" sh -c "git config --global --add safe.directory /var/www/html"
  if docker exec -it "jbt_${version}" sh -c 'git fetch origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/$(git rev-parse --abbrev-ref HEAD))" ]' ; then
    log "jbt_${version} – Local Git clone for branch ${branch} is up to date."
  else
    log "jbt_${version} – Running git pull."
    cp "branch_${version}/package-lock.json" "${TMP}"
    docker exec -it "jbt_${version}" sh -c "git pull"
    log "jbt_${version} – Running composer install, just in case."
    docker exec -it "jbt_${version}" sh -c "composer install"
    if diff -q "branch_${version}/package-lock.json" "$TMP" >/dev/null; then
      log "jbt_${version} – No changes in file 'package-lock.json', skipping npm ci."
    else
      log "jbt_${version} – Changes detected in file 'package-lock.json', running npm ci."
      docker exec -it "jbt_${version}" sh -c "npm ci"
    fi
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    pulled=$((pulled + 1))
  fi
  log "jbt_${version} – Showing Git status for branch ${branch}."
  docker exec -it "jbt_${version}" sh -c "git status"
done

log "Completed ${versionsToPull[@]} with ${pulled} pull's."
