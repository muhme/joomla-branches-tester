#!/bin/bash
#
# clean.sh - Switching PHP in web container to installation with or without Xdebug.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

versionsToChange=()
while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToChange+=("$1")
    shift # Argument is eaten as the version number.
  elif [ "$1" = "on" ]; then
    todo="$1"
    shift # Argument is eaten as enable Xdebug.
  elif [ "$1" = "off" ]; then
    todo="$1"
    shift # Argument is eaten as enable Xdebug.
  else
    log "Mandatory argument 'on' or 'off' is needed"
    log "Optional Joomla version argument could be one or multiple of the following: ${versions}."
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${todo}" ]; then
    error "Please give argument 'on' or 'off'"
    exit 1
fi

# If no version was given, use all.
if [ ${#versionsToChange[@]} -eq 0 ]; then
  versionsToChange=(${allVersions[@]})
fi

# Clean up branch directories if existing
with="/usr/local-with-xdebug/"
without="/usr/local-without-xdebug/"
for version in "${versionsToChange[@]}"; do

  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi

  link=$(docker exec "jbt_${version}" readlink "/usr/local")
  if [ "$todo" = "on" ]; then
    if [ "$link" = "$with" ]; then
      log "jbt_${version} – Xdebug is already enabled."
    else
      log "jbt_${version} – Switching to Xdebug-enabled PHP installation and restarting container."
      docker exec "jbt_${version}" bash -c "rm -f /usr/local && ln -s $with /usr/local"
      docker restart "jbt_${version}"
    fi
  else
    if [ "$link" = "$without" ]; then
      log "jbt_${version} – Xdebug is not currently enabled."
    else
      log "jbt_${version} – Switching to PHP installation without Xdebug and restarting container."
      docker exec "jbt_${version}" bash -c "rm -f /usr/local && ln -s $without /usr/local"
      docker restart "jbt_${version}"
    fi
  fi
done
