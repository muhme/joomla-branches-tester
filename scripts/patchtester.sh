#!/bin/bash
#
# patchtester.sh - Install Joomla Patch Tester on all, one or multiple Docker containers, e.g.
#   scripts/patchtester ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester 44 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester 52 53 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/patchtester'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

function help {
    echo "
    patchtester – Install Joomla Patch Tester on all, one or multiple Web Server Docker containers.
                  Mandatory argument is a valid GitHub personal access token starting with 'ghp_'.
                  Optional Joomla version can be one or more of the following: ${allVersions[@]} (default is all).

                  $(random_quote)
    "
}

versionsToInstall=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
  elif [[ $1 = ghp_* ]]; then
    token="$1"
    shift # Argument is eaten as GitHub token.
  else
    help
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
    log "Using GitHub token from the environment variable 'JBT_GITHUB_TOKEN'"
  else
    help
    error "Please provide a valid GitHub personal access token starting with 'ghp_'."
    exit 1
  fi
fi

# Create latest Patch Tester URL from latest release link redirect.
REPO="joomla-extensions/patchtester"
# Fetch the redirect URL for the latest release
LATEST_TAG_URL=$(curl -s -I https://github.com/${REPO}/releases/latest | grep -i Location | awk '{print $2}' | tr -d '\r')
# e.g. 4.3.3 from https://github.com/joomla-extensions/patchtester/releases/tag/4.3.3
LATEST_TAG=$(basename "${LATEST_TAG_URL}")
log "The latest patch tester release puzzled out as ${LATEST_TAG}"
# e.g. https://github.com/joomla-extensions/patchtester/releases/download/4.3.3/com_patchtester_4.3.3.tar.bz2
PATCHTESTER_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/com_patchtester_${LATEST_TAG}.tar.bz2"
log "Using URL '${PATCHTESTER_URL}'"

failed=0
successful=0
for version in "${versionsToInstall[@]}"
do
  branch=$(branchName "${version}")
  if [ ! -d "branch_${version}" ]; then
    log "jbt-${version} – There is no directory 'branch_${version}', jumped over"
    continue
  fi
  log "jbt-${version} – Installing Joomla Patch Tester"
  docker exec jbt-cypress sh -c " \
    cd /jbt/branch_${version} && \
    unset DISPLAY && \
    cypress run --env patchtester_url=${PATCHTESTER_URL},token=${token} \
                --config specPattern=/jbt/scripts/patchtester.cy.js"
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
  error "Completed ${versionsToInstall[@]} with ${failed} failed and ${successful} successful."
fi
