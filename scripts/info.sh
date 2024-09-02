#!/bin/bash
#
# info.sh - Retrieves Joomla Branches Tester status information.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}"))
unset IFS # map to array

docker_running=false
if docker info >/dev/null 2>&1; then
  docker_running=true
  echo "Docker version $(docker version --format '{{.Server.Version}}') is running with" \
    "$(docker ps -q | wc -l | tr -d ' ') containers and $(docker images -q | wc -l | tr -d ' ') images"
  echo "Standard Containers:"
  for container in jbt_mya jbt_pga jbt_mysql jbt_madb jbt_pg jbt_relay jbt_mail jbt_cypress; do
    if [ "$(docker ps -q -f name=${container})" ]; then
      padded_container=$(printf "%-11s" "$container")
      ports=$(docker port ${container} | awk '{printf "%s; ", $0} END {print ""}' | sed 's/; $/\n/')
      echo "  $padded_container is running, ports: $ports"
    else
      echo "  " && error "${container} is not running."
    fi
  done
else
  log "Docker is NOT running?"
fi

echo "Branches:"
for version in "${allVersions[@]}"; do
  branch_name=$(branchName "${version}")
  echo -n "  Branch ${branch_name}: "
  if ${docker_running}; then
    if [ "$(docker ps -q -f name=jbt_${version})" ]; then
      ports=$(docker port jbt_${version} | awk '{printf "%s; ", $0} END {print ""}' | sed 's/; $/\n/')
      echo -n "jbt_${version} is running, ports: $ports"
    fi
    echo
  fi
  if [ -d "branch_${version}" ]; then
    echo "    /branch_${version}: $(du -ms branch_${version} | awk '{print $1}')MB"
    for git_dir in $(find "branch_${version}" -name ".git"); do
      repo_dir=$(dirname "$git_dir")
      (
        cd "$repo_dir"
        echo "      Repo ${repo_dir}: $(git config --get remote.origin.url), " \
             "Branch: $(git branch --show-current), " \
             "Status: $(git status -s | grep -v -e 'tests/System/integration/install/Installation.cy.js' -e 'cypress.config.local.mjs' | wc -l | tr -d ' ') changes"
      )
    done
  else
    echo "    /branch_${version} is NOT existing"
  fi
done
