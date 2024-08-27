#!/bin/bash
#
# php.sh - Change PHP version on all, one or multiple Docker containers, e.g.
#   scripts/php.sh php8.1
#   scripts/php.sh 51 php8.2
#   scripts/php.sh 52 53 php8.3
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

TMP=/tmp/$(basename $0).$$
trap 'rm -rf $TMP' 0

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

versionsToInstall=()
while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
  elif isValidPHP "$1"; then
    php_version="$1"
    shift # Argument is eaten as PHP version.
  else
    log "Mandatory PHP version is one of: ${JBT_PHP_VERSIONS[@]}."
    log "Optional version can be one of: ${allVersions[@]} (default is all)."
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "$php_version" ]; then
  error "Mandatory PHP version is missing. Please use one of: ${JBT_PHP_VERSIONS[@]}."
  exit 1
fi

# If no version was given, use all.
if [ ${#versionsToInstall[@]} -eq 0 ]; then
  versionsToInstall=(${allVersions[@]})
fi

changed=0
for version in "${versionsToInstall[@]}"
do
  log "jbt_${version} – Stopping Docker container."
  docker compose stop "jbt_${version}"

  log "jbt_${version} – Removing Docker container."
  docker compose rm -f "jbt_${version}" || log "jbt_${version} – Ignoring failure to remove Docker container."

  # Change (simplified by comment marker) e.g.
  # > image: joomla:4.4-php8.1-apache # jbt_44 PHP version
  # < image: joomla:4.4-php8.3-apache # jbt_44 PHP version
  din=$(dockerImageName "$version" "$php_version")
  search="image: joomla:[0-9].[0-9]-php[0-9].[0-9]-apache # jbt_${version} PHP version"
  replace="image: ${din} # jbt_${version} PHP version"
  log "jbt_${version} – Change 'docker-compose.yml' to use '${din}' Docker image for jbt_${version}."
  # Don't use sed inplace editing as it is not supported on macOS's sed.
  sed -E "s|${search}|${replace}|" "docker-compose.yml" > "${TMP}"
  cp "${TMP}" "docker-compose.yml" || sudo cp "${TMP}" "docker-compose.yml"
  # Check it
  occurrences=$(grep -cF "${replace}" "docker-compose.yml" || true)
  if [ "$occurrences" -ne 1 ]; then
      error "The string '${replace}' is not found one times in 'docker-compose.yml' file'."
      exit 1
  fi

  log "jbt_${version} – Building Docker container."
  docker compose build "jbt_${version}"

  log "jbt_${version} – Starting Docker container."
  docker compose up -d "jbt_${version}"

  log "jbt_${version} – Running composer install, just in case."
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    composer install"

  # New image from Docker Hub needs to install at least git for next pull.sh
  log "jbt_${version} – Installing additional packages."
  docker exec -it "jbt_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y git vim nodejs iputils-ping net-tools'

  changed=$((changed + 1))

  log "jbt_${version} – Changed to use $din."

done

log "Completed ${versionsToInstall[@]} with ${changed} changed."
