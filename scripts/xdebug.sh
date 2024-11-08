#!/bin/bash
#
# xdebug.sh - Switches the PHP installation with or without Xdebug in one or more Web Server containers.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/xdebug'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
    echo "
    xdebug – Toggles the PHP installation with or without Xdebug in one or more Joomla web server containers.
             Mandatory argument must be 'on' or 'off'.
             The optional Joomla instance can include one or more of installed: ${allInstalledInstances[*]} (default is all).
             The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.

             $(random_quote)
    "
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
    shift # Argument is eaten as enable Xdebug.
  elif [ "$1" = "off" ]; then
    todo="$1"
    shift # Argument is eaten as enable Xdebug.
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

# Clean up branch directories if existing
with="/usr/local-with-xdebug/"
without="/usr/local-without-xdebug/"
for instance in "${instancesToChange[@]}"; do

  if (( instance <= 39 )); then
    log "jbt-${instance} – No Xdebug available <= Joomla 3.9, jumped over"
    continue
  fi

  link=$(docker exec "jbt-${instance}" readlink "/usr/local")
  if [ "$todo" = "on" ]; then
    if [ "$link" = "$with" ]; then
      log "jbt-${instance} – Xdebug is already enabled"
    else
      log "jbt-${instance} – Switching to Xdebug-enabled PHP installation and restarting container"
      docker exec "jbt-${instance}" bash -c "rm -f /usr/local && ln -s $with /usr/local"
      docker restart "jbt-${instance}"
    fi
  else
    if [ "$link" = "$without" ]; then
      log "jbt-${instance} – Xdebug is not currently enabled"
    else
      log "jbt-${instance} – Switching to PHP installation without Xdebug and restarting container"
      docker exec "jbt-${instance}" bash -c "rm -f /usr/local && ln -s $without /usr/local"
      docker restart "jbt-${instance}"
    fi
  fi
done

if [ "$todo" = "on" ]; then
  log "Creating File '.vscode/launch.json'"
  launch_json=".vscode/launch.json"
  dir=$(dirname "${launch_json}")
  mkdir -p "${dir}" 2>/dev/null || (sudo mkdir -p "${dir}" && sudo 777 "${dir}")
  cat >"${launch_json}" <<EOF
{
    "version": "0.2.0",
    "configurations": [
EOF
  for instance in "${allInstalledInstances[@]}"; do
    if (( instance <= 39 )); then
      continue
    fi
    link=$(docker exec "jbt-${instance}" readlink "/usr/local")
    if [ "$link" = "$with" ]; then
      log "jbt-${instance} – Adding entry 'Listen jbt-${instance}'"
      # As port number for 3.10 use 7910
      cat >>"${launch_json}" <<EOF
        {
            "name": "Listen jbt-${instance}",
            "type": "php",
            "request": "launch",
            "port": 79${instance: -2},
            "pathMappings": {
                "/var/www/html": "\${workspaceFolder}/joomla-${instance}"
            }
        },
EOF
    fi
  done
  cat >>"${launch_json}" <<EOF
    ]
}
EOF
fi
