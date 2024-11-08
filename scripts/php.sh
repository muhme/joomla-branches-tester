#!/bin/bash
#
# php.sh - Change PHP version on all, one or multiple Docker containers, e.g.
#   scripts/php php8.1
#   scripts/php 51 php8.2
#   scripts/php 52 53 php8.3
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/php'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    php – Changes the PHP version on all, one or multiple Joomla web server Docker containers.
          The mandatory PHP version must be one of: ${JBT_PHP_VERSIONS[*]}.
          The optional Joomla version can include one or more of installed: ${allInstalledInstances[*]} (default is all).
          The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

          $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

instancesToPatch=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToPatch+=("$1")
    shift # Argument is eaten as one version number.
  elif isValidPHP "$1"; then
    php_version="$1"
    shift # Argument is eaten as PHP version.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "$php_version" ]; then
  help
  error "Mandatory PHP version is missing. Please use one of: ${JBT_PHP_VERSIONS[*]}."
  exit 1
fi

# If no version was given, use all installed.
if [ ${#instancesToPatch[@]} -eq 0 ]; then
  instancesToPatch=("${allInstalledInstances[@]}")
fi

changed=0
for instance in "${instancesToPatch[@]}"; do

  din=$(dockerImageName "$instance" "$php_version")
  checkDockerImageName "${instance}" "${din:7}" # e.g. 'joomla:5.0-php8.2-apache' as '5.0-php8.2-apache'

  if [ ! -d "joomla-${instance}" ]; then
    log "jbt-${instance} – There is no directory 'joomla-${instance}', jumped over"
    continue
  fi

  log "jbt-${instance} – Stopping Docker container"
  docker compose stop "jbt-${instance}"

  log "jbt-${instance} – Removing Docker container"
  docker compose rm -f "jbt-${instance}" || log "jbt-${instance} – Ignoring failure to remove Docker container"

  # Change (simplified by comment marker) e.g.
  # > image: joomla:4.4-php8.1-apache # jbt-44 image
  # < image: joomla:4.4-php8.3-apache # jbt-44 image
  search="image: joomla:[0-9].[0-9]-php[0-9].[0-9]-apache # jbt-${instance} image"
  replace="image: ${din} # jbt-${instance} image"
  log "jbt-${instance} – Change 'docker-compose.yml' to use '${din}' Docker image for jbt-${instance}"
  # Don't use sed inplace editing as it is not supported on macOS's sed.
  sed -E "s|${search}|${replace}|" "docker-compose.yml" > "${JBT_TMP_FILE}"
  cp "${JBT_TMP_FILE}" "docker-compose.yml" || sudo cp "${JBT_TMP_FILE}" "docker-compose.yml"
  # Check it
  occurrences=$(grep -cF "${replace}" "docker-compose.yml" || true)
  if [ "$occurrences" -ne 1 ]; then
      error "The string '${replace}' is not found one times in 'docker-compose.yml' file'."
      exit 1
  fi

  log "jbt-${instance} – Building Docker container"
  docker compose build "jbt-${instance}"

  log "jbt-${instance} – Starting Docker container"
  docker compose up -d "jbt-${instance}"

  JBT_INTERNAL=42 scripts/setup.sh "${instance}"

  changed=$((changed + 1))

  log "jbt-${instance} – Changed to use $din"

done

log "Completed ${instancesToPatch[*]} with ${changed} changed"
