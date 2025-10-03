#!/bin/bash -e
#
# patchtester.sh - Install or uninstall Joomla Patch Tester on all, one or multiple Docker containers, e.g.
#   scripts/patchtester ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester 44 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#   scripts/patchtester 52 53 ghp_42g8n8uCZtplQNnbNrEWsTrFfQgYAU4711Tc
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 - 2025 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/patchtester'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    patchtester – Installs Joomla Patch Tester on all, one or multiple Joomla web server Docker containers.
                  Requires a GitHub personal access token as an argument, or env var 'JBT_GITHUB_TOKEN', 'GH_TOKEN' or 'GITHUB_TOKEN' set.
                  The optional Joomla version can be one or more of: ${allInstalledInstances[*]} (default is all).
                  The optional Patchtester version, e.g. 4.3.0 (default is latest).
                  The optional 'uninstall' argument to delete a Patch Tester installation (default is 'install').
                  The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

function run_patchtester_install() {
  local instance="$1"
  local patchTesterVersion="$2"
  local token="$3"
  local url="$4"

  log "jbt-${instance} – Installing Joomla Patch Tester version ${patchTesterVersion}"

  docker exec jbt-cypress sh -c "
    cd /jbt/installation/joomla-${instance} && \
    DISPLAY=jbt-novnc:0 \
    CYPRESS_specPattern='/jbt/installation/installPatchtester.cy.js' \
    cypress run --headed --env patchtester_url=${url},token=${token}"
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

patchTesterVersion=""
patchTesterVersionIsLatest=false
install=true
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
  elif [[ "$1" = "install" ]]; then
    install=true
    shift # Argument is eaten up as (default) installation.
  elif [[ "$1" = "uninstall" ]]; then
    install=false
    shift # Argument is eaten up as uninstallation.
  elif [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    patchTesterVersion="$1"
    shift # Argument is eaten as Patch Tester version.
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

if $install; then
  # Check if the given token looks like a GitHub personal access token
  if [ -z "${token}" ]; then
    if [[ "${JBT_GITHUB_TOKEN}" =~ ghp_* ]]; then
      token="${JBT_GITHUB_TOKEN}"
      log "Using GitHub token from the environment variable 'JBT_GITHUB_TOKEN'"
    elif [[ "${GH_TOKEN}" =~ ghp_* ]]; then
      token="${GH_TOKEN}"
      log "Using GitHub token from the environment variable 'GH_TOKEN'"
    elif [[ "${GITHUB_TOKEN}" =~ ghp_* ]]; then
      token="${GITHUB_TOKEN}"
      log "Using GitHub token from the environment variable 'GITHUB_TOKEN'"
    else
      help
      error "Please provide a valid GitHub personal access token starting with 'ghp_'."
      exit 1
    fi
  fi
  # Determine latest Patch Tester version from latest release link redirect.
  REPO="joomla-extensions/patchtester"
  if [ -z "${patchTesterVersion}" ]; then
    # Fetch the redirect URL for the latest release
    latest_tag_URL=$(curl -s -I https://github.com/${REPO}/releases/latest | grep -i Location | awk '{print $2}' | tr -d '\r')
    # e.g. 4.3.3 from https://github.com/joomla-extensions/patchtester/releases/tag/4.3.3
    patchTesterVersion=$(basename "${latest_tag_URL}")
    log "The latest patch tester release puzzled out as ${patchTesterVersion}"
    patchTesterVersionIsLatest=true
  else
    log "Using Patch Tester version ${patchTesterVersion}"
  fi
fi

failed=0
skipped=0
successful=0
for instance in "${instancesToInstall[@]}"; do

  if ! $install; then
    # Uninstall Patch Tester
    id=$(docker exec "jbt-${instance}" bash -c "php cli/joomla.php extension:list --type=component | awk '/com_patchtester/ {print \$2}'")
    if [ -z "${id}" ]; then
      warning "jbt-${instance} – Did not find com_patchtester installed, jumping over"
      skipped=$((skipped + 1))
      continue
    fi
    if docker exec "jbt-${instance}" bash -c "php cli/joomla.php extension:remove ${id} -n"; then
      log "jbt-${instance} – Patch Tester has been successfully removed"
      # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
      successful=$((successful + 1))
    else
      error "jbt-${instance} – Failed to remove the extension com_patchtester with id=${id}"
      failed=$((failed + 1))
    fi
    continue
  fi

  # Install Patch Tester
  if (( instance == 310 || instance <= 41 )); then
    warning "jbt-${instance} – Joomla <= 4.1, skip the installation of Patch Tester"
    skipped=$((skipped + 1))
    continue
  fi

  # e.g. https://github.com/joomla-extensions/patchtester/releases/download/4.3.3/com_patchtester_4.3.3.tar.bz2
  patchtester_url="https://github.com/${REPO}/releases/download/${patchTesterVersion}/com_patchtester_${patchTesterVersion}.tar.bz2"
  log "Using URL '${patchtester_url}'"
  if run_patchtester_install "${instance}" "${patchTesterVersion}" "${token}" "${patchtester_url}"; then
    log "jbt-${instance} – Patch Tester version ${patchTesterVersion} has been successfully installed"
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    # If this a known problem?
    if $patchTesterVersionIsLatest; then
      if [[ $instance -ge 42 && $instance -le 44 && "${patchTesterVersion}" != "4.3.3" ]]; then
        # https://github.com/joomla-extensions/patchtester/issues/378
        usePatchTesterVersion="4.3.3"
      elif [[ $instance -ge 50 && $instance -le 54 && "${patchTesterVersion}" != "4.4.0" ]]; then
        # https://github.com/joomla-extensions/patchtester/issues/383
        usePatchTesterVersion="4.4.0"
      else
        error "jbt-${instance} – Failed to install Patch Tester version ${patchTesterVersion}"
        failed=$((failed + 1))
        continue
      fi
      warning "jbt-${instance} – Installation with latest Patch Tester version ${patchTesterVersion} failed, trying version ${usePatchTesterVersion}"
      patchtester_url="https://github.com/${REPO}/releases/download/${usePatchTesterVersion}/com_patchtester_${usePatchTesterVersion}.tar.bz2"
      log "Using URL '${patchtester_url}'"
      if run_patchtester_install "$instance" "$usePatchTesterVersion" "$token" "${patchtester_url}"; then
        log "jbt-${instance} – Patch Tester version ${usePatchTesterVersion} has been successfully installed"
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
      else
        error "jbt-${instance} – The installation of patch tester version ${usePatchTesterVersion} also failed"
        failed=$((failed + 1))
      fi
    else
      failed=$((failed + 1))
    fi
  fi

done

if [ ${failed} -eq 0 ] ; then
  log "Completed ${instancesToInstall[*]} with ${successful} successful (${skipped} skipped)"
else
  error "Completed ${instancesToInstall[*]} with ${failed} failed and ${successful} successful (${skipped} skipped)."
  if $install; then
    warning "Tip: You can watch the installation with http://host.docker.internal:7005/vnc.html?autoconnect=true&resize=scale"
  fi
fi
