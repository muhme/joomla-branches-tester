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

function help {
    echo "
    patchtester – Installs Joomla Patch Tester on all, one or multiple Joomla web server Docker containers.
                  Requires a GitHub personal access token as an argument (starting with 'ghp_') if 'JBT_GITHUB_TOKEN' is not set.
                  The optional Joomla version can be one or more of: ${allInstalledInstances[*]} (default is all).
                  The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

                  $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

instancesToInstall=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToInstall+=("$1")
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
if [ ${#instancesToInstall[@]} -eq 0 ]; then
  instancesToInstall=("${allInstalledInstances[@]}")
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
skipped=0
successful=0
for instance in "${instancesToInstall[@]}"; do
  if (( instance == 310 || instance <= 41 )); then
    log "jbt-${instance} – Joomla <= 4.1, jumped over"
    skipped=$((skipped + 1))
    continue
  fi
  log "jbt-${instance} – Installing Joomla Patch Tester"
  if docker exec jbt-cypress sh -c "cd /jbt/installation/joomla-${instance} && \
      DISPLAY=jbt-novnc:0 \
      CYPRESS_specPattern='/jbt/installation/installPatchtester.cy.js' \
      cypress run --headed --env patchtester_url=${PATCHTESTER_URL},token=${token}"; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${instancesToInstall[*]} with ${successful} successful (${skipped} skipped)"
else
  error "Completed ${instancesToInstall[*]} with ${failed} failed and ${successful} successful (${skipped} skipped)."
fi
