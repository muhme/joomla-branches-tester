#!/bin/bash
#
# memcached.sh - Switches the Joomla cache handler to Memcached or back to file cache in one or more Web Server containers.
#   scripts/memcached on
#   scripts/memcached 62 on
#   scripts/memcached 53 60 off
#
# Uses the 'jbt-memcached' base Docker container (see configs/docker-compose.base.yml), started and stopped
# on demand by this script, and the 'memcached' PHP extension installed for every Joomla web server
# container (see scripts/setup.sh).
#
# Distributed under the GNU General Public License version 2 or later

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/memcached'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    memcached – Toggles the Joomla cache handler between Memcached and file cache in one or more Joomla web server containers.
            Mandatory argument must be 'on' or 'off'.
            The optional Joomla instance can include one or more of installed: ${allInstalledInstances[*]} (default is all).
            The optional argument 'help' displays this page.
    $(random_quote)"
}

# shellcheck disable=SC2207
allInstalledInstances=($(getAllInstalledInstances))

instancesToChange=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToChange+=("$1")
    shift
  elif [ "$1" = "on" ]; then
    todo="$1"
    shift
  elif [ "$1" = "off" ]; then
    todo="$1"
    shift
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

if [ ${#instancesToChange[@]} -eq 0 ]; then
  # shellcheck disable=SC2207
  instancesToChange=("${allInstalledInstances[@]}")
fi

# jbt-memcached is started/stopped on demand
if [ "${todo}" = "on" ]; then
  log "jbt-memcached – Starting container"
  docker start jbt-memcached > /dev/null
fi

for instance in "${instancesToChange[@]}"; do

  if [ ! -f "joomla-${instance}/configuration.php" ]; then
    warning "jbt-${instance} – No 'configuration.php' found, jumped over"
    continue
  fi

  if [ "${todo}" = "on" ]; then
    if docker exec "jbt-${instance}" bash -c "grep -q \"cache_handler = 'memcached'\" configuration.php"; then
      log "jbt-${instance} – Memcached cache is already enabled"
    else
      log "jbt-${instance} – Enabling Memcached cache handler (host '${JBT_MEMCACHED_HOST:-10.0.0.15}', port ${JBT_MEMCACHED_PORT:-11211})"
      
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 1;|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'memcached';|\" \
        -e \"s|\(public .memcached_server_host =\).*|\1 '${JBT_MEMCACHED_HOST:-10.0.0.15}';|\" \
        -e \"s|\(public .memcached_server_port =\).*|\1 ${JBT_MEMCACHED_PORT:-11211};|\" \
        -e \"s|\(public .session_memcached_server_host =\).*|\1 '${JBT_MEMCACHED_HOST:-10.0.0.15}';|\" \
        -e \"s|\(public .session_memcached_server_port =\).*|\1 ${JBT_MEMCACHED_PORT:-11211};|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"

      log "jbt-${instance} – Reloading Apache to pick up the new 'configuration.php'"
      docker exec "jbt-${instance}" bash -c "apache2ctl graceful"
    fi
  else
    if docker exec "jbt-${instance}" bash -c "grep -q \"cache_handler = 'file'\" configuration.php"; then
      log "jbt-${instance} – Memcached cache is already disabled"
    else
      log "jbt-${instance} – Disabling Memcached, switching back to file cache handler"
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .caching =\).*|\1 0;|\" \
        -e \"s|\(public .cache_handler =\).*|\1 'file';|\" \
        -e \"s|\(public .memcached_server_host =\).*|\1 'localhost';|\" \
        -e \"s|\(public .memcached_server_port =\).*|\1 11211;|\" \
        -e \"s|\(public .session_memcached_server_host =\).*|\1 'localhost';|\" \
        -e \"s|\(public .session_memcached_server_port =\).*|\1 11211;|\" \
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
  stillUsed=false
  for instance in "${allInstalledInstances[@]}"; do
    if [ -f "joomla-${instance}/configuration.php" ] && grep -q "cache_handler = 'memcached'" "joomla-${instance}/configuration.php"; then
      stillUsed=true
      break
    fi
  done
  if [ "${stillUsed}" = false ]; then
    log "jbt-memcached – Stopping container, no Joomla instance is using it anymore"
    docker stop jbt-memcached > /dev/null
  else
    log "jbt-memcached – Keeping container running, still used by instance '${instance}'"
  fi
fi
