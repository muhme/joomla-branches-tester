#!/bin/bash -e
#
# export.sh - Exports a Joomla instance as database dump and file backup.
#   export 54 -> exports/54-261014.sql and exports/54-261014.zip
#
# Distributed under the GNU General Public License version 2 or later
# Copyright (c) 2024 - 2026 Heiko Lübbe and contributors
# https://github.com/muhme/joomla-branches-tester

set -Eeuo pipefail

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/export'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    export – Exports a Joomla instance, the opposite of 'import'.
             Mandatory argument is the Joomla version number, e.g. 54.
             The optional argument 'help' displays this page. For full details see https://bit.ly/JBT--README.
    $(random_quote)"
}

instance=""
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [[ "$1" =~ ^[0-9]+$ && -z "${instance}" ]]; then
    instance="$1"
    shift # Argument is eaten as Joomla version
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${instance}" ]; then
  help
  error "The mandatory Joomla version number is missing, e.g. 54."
  exit 1
fi

joomla_dir="joomla-${instance}"
configuration="${joomla_dir}/configuration.php"
if [ ! -f "${configuration}" ]; then
  error "Missing '${configuration}', is Joomla version ${instance} installed?"
  exit 1
fi

# Read a public property from configuration.php, e.g. 'host'
function configValue {
  sed -nE "s/^[[:space:]]*public \\\$$1 = '([^']*)'.*/\1/p" "${configuration}" | head -n 1
}

dbhost=$(configValue host)
dbtype=$(configValue dbtype)
database=$(configValue db)
if [ -z "${dbhost}" ] || [ -z "${database}" ]; then
  error "Could not read database host and name from '${configuration}'."
  exit 1
fi

# Find unused base name, e.g. 54-261014, 54-261014-2, ...
mkdir -p exports
base="exports/${instance}-$(date '+%y%m%d')"
name="${base}"
counter=1
while [ -e "${name}.sql" ] || [ -e "${name}.zip" ]; do
  counter=$((counter + 1))
  name="${base}-${counter}"
done

log "jbt-${instance} – Exporting database ${database} from ${dbhost} (${dbtype}) to ${name}.sql"
if [ "${dbhost}" = "jbt-pg" ] || [ "${dbtype}" = "pgsql" ]; then
  docker exec "${dbhost}" pg_dump -U postgres "${database}" > "${name}.sql"
else
  # MariaDB images may only provide mariadb-dump
  docker exec "${dbhost}" bash -c "command -v mysqldump >/dev/null && d=mysqldump || d=mariadb-dump; \
    \${d} -u root -proot --single-transaction --routines --triggers ${database}" > "${name}.sql"
fi

log "jbt-${instance} – Exporting files from ${joomla_dir} to ${name}.zip"
zip_abs="$(pwd)/${name}.zip"
( cd "${joomla_dir}" && zip -qr "${zip_abs}" . ) || ( cd "${joomla_dir}" && sudo zip -qr "${zip_abs}" . )

log "jbt-${instance} – Exported ${name}.sql ($(du -h "${name}.sql" | cut -f1)) and ${name}.zip ($(du -h "${name}.zip" | cut -f1))"
