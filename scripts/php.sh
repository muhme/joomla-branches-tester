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
          The optional Joomla version can be one or more of: ${allVersions[*]} (default is all).
          The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

          $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getBranches))

versionsToPatch=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${allVersions[*]}"; then
    versionsToPatch+=("$1")
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

# If no version was given, use all.
if [ ${#versionsToPatch[@]} -eq 0 ]; then
  versionsToPatch=("${allVersions[@]}")
fi

changed=0
for version in "${versionsToPatch[@]}"; do

  if [ ! -d "branch-${version}" ]; then
    log "jbt-${version} – There is no directory 'branch-${version}', jumped over"
    continue
  fi

  log "jbt-${version} – Stopping Docker container"
  docker compose stop "jbt-${version}"

  log "jbt-${version} – Removing Docker container"
  docker compose rm -f "jbt-${version}" || log "jbt-${version} – Ignoring failure to remove Docker container"

  # Change (simplified by comment marker) e.g.
  # > image: joomla:4.4-php8.1-apache # jbt-44 PHP version
  # < image: joomla:4.4-php8.3-apache # jbt-44 PHP version
  din=$(dockerImageName "$version" "$php_version")
  search="image: joomla:[0-9].[0-9]-php[0-9].[0-9]-apache # jbt-${version} PHP version"
  replace="image: ${din} # jbt-${version} PHP version"
  log "jbt-${version} – Change 'docker-compose.yml' to use '${din}' Docker image for jbt-${version}"
  # Don't use sed inplace editing as it is not supported on macOS's sed.
  sed -E "s|${search}|${replace}|" "docker-compose.yml" > "${JBT_TMP_FILE}"
  cp "${JBT_TMP_FILE}" "docker-compose.yml" || sudo cp "${JBT_TMP_FILE}" "docker-compose.yml"
  # Check it
  occurrences=$(grep -cF "${replace}" "docker-compose.yml" || true)
  if [ "$occurrences" -ne 1 ]; then
      error "The string '${replace}' is not found one times in 'docker-compose.yml' file'."
      exit 1
  fi

  log "jbt-${version} – Building Docker container"
  docker compose build "jbt-${version}"

  log "jbt-${version} – Starting Docker container"
  docker compose up -d "jbt-${version}"

  JBT_INTERNAL=42 scripts/setup.sh "${version}"

  changed=$((changed + 1))

  log "jbt-${version} – Changed to use $din"

done

log "Completed ${versionsToPatch[*]} with ${changed} changed"
