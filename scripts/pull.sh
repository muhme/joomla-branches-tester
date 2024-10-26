#!/bin/bash
#
# pull.sh - Running git pull and more on all, one or multiple branches, e.g.
#   scripts/pull
#   scripts/pull 51
#   scripts/pull 52 53
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/pull'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    pull – Executes 'git pull' on one or multiple Joomla web server containers.
           Runs 'composer install' if changes are detected and 'npm clean install' if needed.
           Optional Joomla version can be one or more of: ${allVersions[*]} (default is all).
           The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

           $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getBranches))

versionsToPull=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${allVersions[*]}"; then
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
  versionsToPull=("${allVersions[@]}")
fi

pulled=0
for version in "${versionsToPull[@]}"; do
  branch=$(branchName "${version}")
  if [ ! -d "branch-${version}" ]; then
    log "jbt-${version} – There is no directory 'branch-${version}', jumped over"
    continue
  fi
  if [ ! -d "branch-${version}/.git" ]; then
    log "jbt-${version} – There is no directory 'branch-${version}/.git', grafted Joomla package?, jumped over"
    continue
  fi
  log "jbt-${version} – Running Git fetch origin for ${branch}"
  # Prevent dubious ownership in repository
  docker exec "jbt-${version}" sh -c "git config --global --add safe.directory /var/www/html"
  if docker exec "jbt-${version}" sh -c 'git fetch origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/$(git rev-parse --abbrev-ref HEAD))" ]' ; then
    log "jbt-${version} – Local Git clone for branch ${branch} is up to date"
  else
    log "jbt-${version} – Running git pull"
    cp "branch-${version}/package-lock.json" "${JBT_TMP_FILE}"
    docker exec "jbt-${version}" sh -c "git pull"
    log "jbt-${version} – Running composer install, just in case"
    docker exec "jbt-${version}" sh -c "composer install"
    if diff -q "branch-${version}/package-lock.json" "$JBT_TMP_FILE" >/dev/null; then
      log "jbt-${version} – No changes in file 'package-lock.json', skipping npm ci"
    else
      log "jbt-${version} – Changes detected in file 'package-lock.json', running npm ci"
      docker exec "jbt-${version}" sh -c "npm ci"
    fi
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    pulled=$((pulled + 1))
  fi
  log "jbt-${version} – Showing Git status for branch ${branch}"
  docker exec "jbt-${version}" sh -c "git status"
done

log "Completed ${versionsToPull[*]} with ${pulled} pull's"
