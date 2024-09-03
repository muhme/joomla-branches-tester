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
  for container in "${JBT_BASE_CONTAINERS[@]}"; do
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

for version in "${allVersions[@]}"; do
  branch_name=$(branchName "${version}")
  echo "Branch ${branch_name}:"
  if ${docker_running}; then
    if [ "$(docker ps -q -f name=jbt_${version})" ]; then
      ports=$(docker port jbt_${version} | awk '{printf "%s; ", $0} END {print ""}' | sed 's/; $/\n/')
      echo "  jbt_${version} is running, ports: $ports"
    else
      echo "  jbt_${version} is NOT running"
    fi
  fi
  if [ -d "branch_${version}" ]; then
      version_file="branch_${version}/libraries/src/Version.php"
    if [ -f "${version_file}" ]; then
      product=$(grep "public const PRODUCT" "${version_file}" | awk -F"'" '{print $2}')
      major_version=$(grep "public const MAJOR_VERSION" "${version_file}" | awk -F" " '{print $NF}' | tr -d ';')
      minor_version=$(grep "public const MINOR_VERSION" "${version_file}" | awk -F" " '{print $NF}' | tr -d ';')
      patch_version=$(grep "public const PATCH_VERSION" "${version_file}" | awk -F" " '{print $NF}' | tr -d ';')
      extra_version=$(grep "public const EXTRA_VERSION" "${version_file}" | awk -F"'" '{print $NF}' | tr -d ';')
      dev_status=$(grep "public const DEV_STATUS" "${version_file}" | awk -F"'" '{print $2}')
      echo -n "  Version: $product $major_version.$minor_version.$patch_version"
      if [ ! -z "${extra_version}"]; then
        echo "-$extra_version"
      fi
      echo " ${dev_status}"
    fi
    echo "  /branch_${version}: $(du -ms branch_${version} | awk '{print $1}')MB"
    for git_dir in $(find "branch_${version}" -name ".git"); do
      repo_dir=$(dirname "$git_dir")
      (
        cd "$repo_dir"
        echo "  Repository ${repo_dir}: $(git config --get remote.origin.url), " \
             "Branch: $(git branch --show-current), " \
             "Status: $(git status -s | grep -v -e 'tests/System/integration/install/Installation.cy.js' -e 'cypress.config.local.mjs' | wc -l | tr -d ' ') changes"
      )
    done
  else
    echo "  /branch_${version} is NOT existing"
  fi
done