#!/bin/bash
#
# redis.sh - Switches the Joomla cache handler to Redis or back to file cache in one or more Web Server containers.
#   scripts/redis on
#   scripts/redis 62 on
#   scripts/redis 53 60 off
#
# Uses the 'jbt-redis' base Docker container (see configs/docker-compose.base.yml), started and stopped
# on demand by this script, and the 'redis' PHP extension installed for every Joomla web server
# container (see scripts/setup.sh).
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

# jbt-redis is only needed while at least one instance actually uses it, so it is started/stopped on demand.
if [ "${todo}" = "on" ]; then
  log "jbt-redis – Starting container"
  docker start jbt-redis > /dev/null
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
      # Field names as used by Joomla in 'configuration.php', see 'installation/configuration.php-dist':
      #   Cache:   $caching, $cache_handler, $redis_server_host, $redis_server_port
      #   Session: $session_redis_server_host, $session_redis_server_port
      #            (only used if $session_handler is separately set to 'redis', not changed here)
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 1;|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'redis';|\" \
        -e \"s|\(public .redis_server_host =\).*|\1 '${JBT_REDIS_HOST}';|\" \
        -e \"s|\(public .redis_server_port =\).*|\1 ${JBT_REDIS_PORT};|\" \
        -e \"s|\(public .session_redis_server_host =\).*|\1 '${JBT_REDIS_HOST}';|\" \
        -e \"s|\(public .session_redis_server_port =\).*|\1 ${JBT_REDIS_PORT};|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"
      # Apache worker processes (and, if enabled, PHP OPcache) may have already loaded the old
      # 'configuration.php' into memory, so a graceful reload is needed for the change to take effect.
      log "jbt-${instance} – Reloading Apache to pick up the new 'configuration.php'"
      docker exec "jbt-${instance}" bash -c "apache2ctl graceful"
    fi
  else
    if docker exec "jbt-${instance}" bash -c "grep -q \"cache_handler = 'file'\" configuration.php"; then
      log "jbt-${instance} – Redis cache is already disabled"
    else
      log "jbt-${instance} – Disabling Redis, switching back to file cache handler"
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 0;|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'file';|\" \
        -e \"s|\(public .redis_server_host =\).*|\1 'localhost';|\" \
        -e \"s|\(public .redis_server_port =\).*|\1 6379;|\" \
        -e \"s|\(public .session_redis_server_host =\).*|\1 'localhost';|\" \
        -e \"s|\(public .session_redis_server_port =\).*|\1 6379;|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"
      log "jbt-${instance} – Reloading Apache to pick up the new 'configuration.php'"
      docker exec "jbt-${instance}" bash -c "apache2ctl graceful"
    fi
  fi
done

if [ "${todo}" = "off" ]; then
  # Check across *all* installed instances, not only the ones just changed, whether Redis is still
  # in use anywhere, since jbt-redis is one shared base container (see configs/docker-compose.base.yml).
  stillUsed=false
  for instance in "${allInstalledInstances[@]}"; do
    if [ -f "joomla-${instance}/configuration.php" ] && grep -q "cache_handler = 'redis'" "joomla-${instance}/configuration.php"; then
      stillUsed=true
      break
    fi
  done
  if [ "${stillUsed}" = false ]; then
    log "jbt-redis – Stopping container, no Joomla instance is using it anymore"
    docker stop jbt-redis > /dev/null
  else
    log "jbt-redis – Keeping container running, still used by instance '${instance}'"
  fi
fi
