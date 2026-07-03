#!/bin/bash
#
# redis.sh - Switches the Joomla cache handler to Redis or back to file cache in one or more Web Server containers.
#   scripts/redis on
#   scripts/redis 62 on
#   scripts/redis 53 60 off
#
# Uses the always running 'jbt-redis' base Docker container (see configs/docker-compose.base.yml)
# and the 'redis' PHP extension installed for every Joomla web server container (see scripts/setup.sh).
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2026 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/redis'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    redis – Toggles the Joomla cache handler between Redis and file cache in one or more Joomla web server containers.
            Mandatory argument must be 'on' or 'off'.
            The optional Joomla instance can include one or more of installed: ${allInstalledInstances[*]} (default is all).
            The optional argument 'help' displays this page. For full details see https://bit.ly/JBT--README.
    $(random_quote)"
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

instancesToChange=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToChange+=("$1")
    shift # Argument is eaten as one version number.
  elif [ "$1" = "on" ]; then
    todo="$1"
    shift # Argument is eaten as enable Redis.
  elif [ "$1" = "off" ]; then
    todo="$1"
    shift # Argument is eaten as disable Redis.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${todo}" ]; then
    help
    error "Please provide the argument 'on' or 'off'."
    exit 1
fi

# If no version was given, use all.
if [ ${#instancesToChange[@]} -eq 0 ]; then
  # shellcheck disable=SC2207 # There are no spaces in version numbers
  instancesToChange=("${allInstalledInstances[@]}")
fi

for instance in "${instancesToChange[@]}"; do

  if [ ! -f "joomla-${instance}/configuration.php" ]; then
    warning "jbt-${instance} – No 'configuration.php' found, Joomla is probably not installed yet, jumped over"
    continue
  fi

  if [ "${todo}" = "on" ]; then
    if docker exec "jbt-${instance}" bash -c "grep -q \"cache_handler = 'redis'\" configuration.php"; then
      log "jbt-${instance} – Redis cache is already enabled"
    else
      log "jbt-${instance} – Enabling Redis cache handler (host '${JBT_REDIS_HOST}', port ${JBT_REDIS_PORT})"
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 '1';|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'redis';|\" \
        -e \"s|\(public .redis_persistent =\).*|\1 '0';|\" \
        -e \"s|\(public .redis_host =\).*|\1 '${JBT_REDIS_HOST}';|\" \
        -e \"s|\(public .redis_port =\).*|\1 '${JBT_REDIS_PORT}';|\" \
        -e \"s|\(public .redis_db =\).*|\1 '0';|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"
    fi
  else
    if docker exec "jbt-${instance}" bash -c "grep -q \"cache_handler = 'file'\" configuration.php"; then
      log "jbt-${instance} – Redis cache is already disabled"
    else
      log "jbt-${instance} – Disabling Redis, switching back to file cache handler"
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 '0';|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'file';|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"
    fi
  fi
done
