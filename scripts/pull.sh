#!/bin/bash
#
# pull.sh - Running git pull and more on all, one or multiple branches, e.g.
#   scripts/pull
#   scripts/pull 51
#   scripts/pull 52 53
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2026 Heiko Lübbe
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
           Optional Joomla instance can include one or more of installed: ${allInstalledInstances[*]} (default is all).
           The optional argument 'help' displays this page. For full details see https://bit.ly/JBT--README.
    $(random_quote)"
}

# shellcheck disable=SC2207 # There are no spaces in instance numbers
allInstalledInstances=($(getAllInstalledInstances))

instancesToPull=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToPull+=("$1")
    shift # Argument is eaten as one version number.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# If no instance was given, use all.
if [ ${#instancesToPull[@]} -eq 0 ]; then
  instancesToPull=("${allInstalledInstances[@]}")
fi

pulled=0
for instance in "${instancesToPull[@]}"; do
  if [ ! -d "joomla-${instance}/.git" ]; then
    log "jbt-${instance} – There is no directory 'joomla-${instance}/.git', grafted Joomla package?, jumped over"
    continue
  fi
  branch=$(docker exec "jbt-${instance}" sh -c "git branch -r --contains HEAD | head -1 | sed 's|[ ]*origin/||'")
  if [ -z "${branch}" ]; then
    log "jbt-${instance} – Not a Git branch, jumped over"
    continue
  fi
  log "jbt-${instance} – Running Git fetch origin for ${branch}"
  # Prevent dubious ownership in repository
  docker exec "jbt-${instance}" sh -c "git config --global --add safe.directory /var/www/html"
  if docker exec "jbt-${instance}" sh -c 'git fetch origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/$(git rev-parse --abbrev-ref HEAD))" ]' ; then
    log "jbt-${instance} – Local Git clone for branch ${branch} is up to date"
  else
    log "jbt-${instance} – Running git pull"
    cp "joomla-${instance}/package-lock.json" "${JBT_TMP_FILE}"
    docker exec "jbt-${instance}" sh -c "git pull"
    log "jbt-${instance} – Running composer install, just in case"
    docker exec "jbt-${instance}" sh -c "composer install"
    if diff -q "joomla-${instance}/package-lock.json" "$JBT_TMP_FILE" >/dev/null; then
      log "jbt-${instance} – No changes in file 'package-lock.json', skipping npm ci"
    else
      log "jbt-${instance} – Changes detected in file 'package-lock.json', running npm ci"
      docker exec "jbt-${instance}" sh -c "npm ci"
    fi
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    pulled=$((pulled + 1))
  fi
  log "jbt-${instance} – Showing Git status for branch ${branch}"
  docker exec "jbt-${instance}" sh -c "git status"
done

log "Completed ${instancesToPull[*]} with ${pulled} pull's"
