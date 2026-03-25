#!/bin/bash -e
#
# import.sh - Imports Joomla export.
#   import site.sql site.zip
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2026 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

set -Eeuo pipefail

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/import'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

# Detect database host from SQL file
#
function detectDatabaseFromSql {
  local sql_file="$1"
  local header
  header=$(head -5 "${sql_file}")

  # mysqldump/mariadb-dump write the tool name in the very first comment line
  if echo "${header}" | grep -qi 'PostgreSQL database dump'; then
    echo "jbt-pg"
    return 0
  fi
  if echo "${header}" | grep -qi 'MariaDB dump'; then
    echo "jbt-madb"
    return 0
  fi
  if echo "${header}" | grep -qi 'MySQL dump'; then
    echo "jbt-mysql"
    return 0
  fi

  # Fallback: scan deeper for distinctive syntax
  if head -1000 "${sql_file}" | grep -qiE '(CREATE SEQUENCE|COPY .* FROM stdin|SELECT pg_catalog)'; then
    echo "jbt-pg"
    return 0
  fi
  if head -1000 "${sql_file}" | grep -qi 'MariaDB'; then
    echo "jbt-madb"
    return 0
  fi

  # Default to MariaDB if uncertain
  echo "jbt-madb"
}

function help {
  echo "
    import – Imports a Joomla export.
             Mandatory arguments are database dump file as *.sql and file backup as *.zip.
             Joomla version is auto-detected from libraries/src/Version.php inside the ZIP.
             The optional argument 'help' displays this page. For full details see https://bit.ly/JBT--README.
    $(random_quote)"
}

instance=""
zip_archive=""
database_dump=""
dbhost=""
dbtype=""
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [[ "$1" == *.sql ]]; then
    database_dump="$1"
    shift # Argument is eaten as database dump
  elif [[ "$1" == *.zip ]]; then
    zip_archive="$1"
    shift # Argument is eaten as file backup
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "${zip_archive}" ]; then
  help
  error "The mandatory ZIP file containing the Joomla files is missing. Please give as *.zip."
  exit 1
fi
if [ -z "${database_dump}" ]; then
  help
  error "Mandatory Joomla database export file is missing. Please give as *.sql."
  exit 1
fi

version_file_in_zip=$(unzip -Z1 "${zip_archive}" | grep -E '(^|/)libraries/src/Version.php$' | head -n 1 || true)

if [ -z "${version_file_in_zip}" ]; then
  error "Could not find libraries/src/Version.php in ZIP '${zip_archive}'."
  exit 1
fi

major_version=$(unzip -p "${zip_archive}" "${version_file_in_zip}" | sed -nE 's/^[[:space:]]*public const MAJOR_VERSION = ([0-9]+);/\1/p' | head -n 1)
minor_version=$(unzip -p "${zip_archive}" "${version_file_in_zip}" | sed -nE 's/^[[:space:]]*public const MINOR_VERSION = ([0-9]+);/\1/p' | head -n 1)

if [ -z "${major_version}" ] || [ -z "${minor_version}" ]; then
  error "Could not read MAJOR_VERSION/MINOR_VERSION from ${version_file_in_zip} in ZIP '${zip_archive}'."
  exit 1
fi

instance="${major_version}${minor_version}"
log "Detected Joomla major and minor version as ${instance}"

dbhost=$(detectDatabaseFromSql "${database_dump}")

if [ "${dbhost}" = "jbt-pg" ]; then
  dbtype="pgsql"
  database_variant="pgsql"
elif [ "${dbhost}" = "jbt-madb" ]; then
  dbtype="mysqli"
  database_variant="mariadbi"
else
  dbtype="mysqli"
  database_variant="mysqli"
fi

log "jbt-${instance} – Using dbhost ${dbhost} and dbtype ${dbtype}"

if [ ! -d "joomla-${instance}" ]; then
  scripts/create.sh recreate empty "${instance}" "${database_variant}"
fi

name="$(superUserName "${instance}")"
email="$(superUserEmail "${instance}")"

log "jbt-${instance} – Clean up files"
rm -rf "joomla-${instance}"/* "joomla-${instance}"/.??* || sudo rm -rf "joomla-${instance}"/* "joomla-${instance}"/.??*

log "jbt-${instance} – Extracting files"
( cd "joomla-${instance}" ; unzip -q "${zip_archive}" )

log "jbt-${instance} – Changing ownership to 'www-data' for all files and directories"
docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html'

database="test_joomla_${instance}"

if [ "${dbhost}" = "jbt-pg" ]; then
  db_container="${dbhost}"
  log "jbt-${instance} – Drop PostgreSQL database ${database} if exists"
  docker exec -it "${db_container}" psql -U postgres -c "DROP DATABASE IF EXISTS ${database};"

  log "jbt-${instance} – Creating a new PostgreSQL database ${database}"
  docker exec -it "${db_container}" psql -U postgres -c "CREATE DATABASE ${database};"

  # Using the same database prefix as configured in configuration.php
  log "jbt-${instance} – Importing PostgreSQL database dump"
  docker exec -i "${db_container}" psql -U postgres -d "${database}" < "${database_dump}"

else
  # MySQL/MariaDB
  db_container="${dbhost}"

  log "jbt-${instance} – Drop ${db_container} database ${database} if exists"
  docker exec -it "${db_container}" bash -c "mysql -u root -proot -e 'DROP DATABASE IF EXISTS ${database}';"

  log "jbt-${instance} – Creating a new ${dbtype} database ${database}"
  docker exec -it "${db_container}" bash -c "mysql -u root -proot -e 'CREATE DATABASE ${database}'"

  # Using the same database prefix as configured in configuration.php
  log "jbt-${instance} – Importing ${dbtype} database dump"
  docker exec -i "${db_container}" bash -c "mysql -u root -proot ${database}" < "${database_dump}"
fi

log "jbt-${instance} – Save configuration.php as configuration.php.orig and adopting"
rm -rf "joomla-${instance}/configuration.php.orig" || rm -rf sudo "joomla-${instance}/configuration.php.orig"
cp -p "joomla-${instance}/configuration.php" "joomla-${instance}/configuration.php.orig" || \
  sudo cp -p "joomla-${instance}/configuration.php" "joomla-${instance}/configuration.php.orig"
adjustJoomlaConfigurationForJBT "${instance}"

# Since we get an access error when changing the ownership, even as root user,
# we create configuration.php.new and rename it.
docker exec "jbt-${instance}" bash -c "sed \
  -e \"s|\(public .host =\).*|\1 '${db_container}';|\" \\
  -e \"s|\(public .dbtype =\).*|\1 '${dbtype}';|\" \
  -e \"s|\(public .db =\).*|\1 'test_joomla_${instance}';|\" \
  -e \"s|\(public .user =\).*|\1 'root';|\" \
  -e \"s|\(public .password =\).*|\1 'root';|\" \
  -e \"s|\(public .log_path =\).*|\1 '/var/www/html/administrator/logs';|\" \
  -e \"s|\(public .tmp_path =\).*|\1 '/var/www/html/tmp';|\" \
  configuration.php > configuration.php.new && \
  mv configuration.php.new configuration.php && \
  chown www-data:www-data configuration.php && \
  chmod 0444 configuration.php"

configureJoomlaDebugAndLog "${instance}"

if docker exec "jbt-${instance}" php cli/joomla.php user:list | grep -q "${JBT_SUPERUSER_USERNAME}.*Super Users"; then
  log "jbt-${instance} – Joomla super user '${JBT_SUPERUSER_USERNAME}' already exists, skipping creation"
else
  log "jbt-${instance} – Creating Joomla super user '${JBT_SUPERUSER_USERNAME}' with password '${JBT_SUPERUSER_PASSWORD}'"
  docker exec "jbt-${instance}" bash -c "php cli/joomla.php user:add \
      --username='${JBT_SUPERUSER_USERNAME}' \
      --name='${name}' \
      --password='${JBT_SUPERUSER_PASSWORD}' \
      --email='${email}' \
      --usergroup='Super Users'"
fi

if [ -f "joomla-${instance}/.htaccess" ]; then
  warning "jbt-${instance} – File 'joomla-${instance}/.htaccess' exists'"
  log "jbt-${instance} – Save .htaccess as .htaccess.orig"
  rm -f "joomla-${instance}/.htaccess.orig" || sudo rm -f "joomla-${instance}/.htaccess.orig"
  cp -p "joomla-${instance}/.htaccess" "joomla-${instance}/.htaccess.orig" || \
    sudo cp -p "joomla-${instance}/.htaccess" "joomla-${instance}/.htaccess.orig"

  if grep -qE '^[[:space:]]*RewriteCond[[:space:]]+%\{HTTP_HOST\}' "joomla-${instance}/.htaccess"; then
    log "jbt-${instance} – Commenting out HTTP_HOST redirect in .htaccess"
    awk '
      BEGIN { comment_next_rule = 0 }
      {
        if (comment_next_rule == 1) {
          if ($0 ~ /^[[:space:]]*RewriteRule[[:space:]]/ && $0 !~ /^[[:space:]]*#/) {
            print "# " $0
          } else {
            print
          }
          comment_next_rule = 0
          next
        }

        if ($0 ~ /^[[:space:]]*RewriteCond[[:space:]]+%\{HTTP_HOST\}/ && $0 !~ /^[[:space:]]*#/) {
          print "# " $0
          comment_next_rule = 1
          next
        }

        print
      }
    ' "joomla-${instance}/.htaccess" > "joomla-${instance}/.htaccess.new"
    mv "joomla-${instance}/.htaccess.new" "joomla-${instance}/.htaccess"
  fi
fi
