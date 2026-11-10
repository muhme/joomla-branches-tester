#!/bin/bash
#
# database-count.sh - Functions to count database objects before and after System Tests
#                     Only sourced internally by scripts/test.sh
#
# Distributed under the GNU General Public License version 2 or later
# Copyright (c) 2024 - 2026 Heiko Lübbe and contributors
# https://github.com/muhme/joomla-branches-tester

if [ "${JBT_INTERNAL}" != "42" ]; then
  help
  error "This '${BASH_SOURCE[0]}' is intended to be sourced from 'scripts/test.sh' only."
  exit 1
fi

# Tables to exclude from database change tracking
# These tables change during normal Joomla operation and are not test-related
function getExcludedTablesSQL() {
  local dbprefix="$1"
  cat << 'SQL'
    AND TABLE_NAME NOT IN (
      '%_action_logs',
      '%_history',
      '%_session',
      '%_finder_filters',
      '%_finder_filters_access',
      '%_finder_links',
      '%_finder_links_terms',
      '%_finder_links_termstaxonomy',
      '%_finder_taxonomy',
      '%_finder_taxonomy_map',
      '%_finder_terms'
    )
SQL
}

# Get database configuration from Joomla instance
# Returns: dbtype, dbhost, dbname, dbprefix, dbuser, dbpass
function getDbConfig() {
  local instance="$1"
  local config_file="joomla-${instance}/configuration.php"

  if [ ! -f "${config_file}" ]; then
    error "Configuration file not found: ${config_file}"
    return 1
  fi

  # Extract database configuration from PHP configuration file
  # Must match exactly "public $dbtype = 'value';" pattern (not dbencryption, etc.)
  dbtype=$(grep "^[[:space:]]*public \$dbtype = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")
  dbhost=$(grep "^[[:space:]]*public \$host = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")
  dbname=$(grep "^[[:space:]]*public \$db = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")
  dbprefix=$(grep "^[[:space:]]*public \$dbprefix = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")
  dbuser=$(grep "^[[:space:]]*public \$user = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")
  dbpass=$(grep "^[[:space:]]*public \$password = " "${config_file}" | sed "s/^[^=]*= '\([^']*\)'.*/\1/")

  if [ -z "${dbtype}" ] || [ -z "${dbhost}" ] || [ -z "${dbname}" ]; then
    error "Could not extract database configuration from ${config_file}"
    error "  dbtype='${dbtype}' dbhost='${dbhost}' dbname='${dbname}'"
    return 1
  fi
}

# Count MySQL/MariaDB tables and rows
function countMySQLObjects() {
  local docker_host="$1" dbname="$2" dbuser="$3" dbpass="$4" dbprefix="$5"
  local count_file="$6" error_file="${6}.error"

  local mysql_cmd="mysql -u ${dbuser} -p'${dbpass}' ${dbname}"

  # Count objects: tables with row count, sorted by table name
  # Exclude system tables that change during normal Joomla operation
  if ! docker exec "${docker_host}" bash -c "${mysql_cmd} -s -N -e \"
SELECT CONCAT(TABLE_NAME, '$(printf ' ')', TABLE_ROWS)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = '${dbname}'
  AND TABLE_NAME NOT LIKE '${dbprefix}action_logs'
  AND TABLE_NAME NOT LIKE '${dbprefix}history'
  AND TABLE_NAME NOT LIKE '${dbprefix}session'
  AND TABLE_NAME NOT LIKE '${dbprefix}finder_%'
ORDER BY TABLE_NAME;
\"" 2>"${error_file}" > "${count_file}"; then
    local err_msg
    err_msg=$(cat "${error_file}" 2>/dev/null || echo "Unknown error")
    error "Failed to query MySQL/MariaDB database ${dbname} on ${docker_host}: ${err_msg}"
    rm -f "${error_file}"
    return 1
  fi

  rm -f "${error_file}"
  if [ ! -s "${count_file}" ]; then
    error "Database query returned no results for ${dbname} on ${docker_host}"
    return 1
  fi
}

# Count PostgreSQL tables and rows
function countPostgreSQLObjects() {
  local dbname="$1" dbuser="$2" dbpass="$3" dbprefix="$4"
  local count_file="$5" error_file="${5}.error"

  local psql_cmd="PGPASSWORD='${dbpass}' psql -h localhost -U ${dbuser} -d ${dbname}"

  # Count objects: tables with row count, sorted by table name
  # Tuples only (-t) and unaligned (-A) for clean output
  # Exclude system tables that change during normal Joomla operation
  if ! docker exec "jbt-pg" bash -c "${psql_cmd} -t -A -c \"
SELECT relname || '$(printf ' ')' || n_live_tup
FROM pg_stat_user_tables
WHERE relname NOT LIKE '${dbprefix}action_logs'
  AND relname NOT LIKE '${dbprefix}history'
  AND relname NOT LIKE '${dbprefix}session'
  AND relname NOT LIKE '${dbprefix}finder_%'
ORDER BY relname;
\"" 2>"${error_file}" > "${count_file}"; then
    local err_msg
    err_msg=$(cat "${error_file}" 2>/dev/null || echo "Unknown error")
    error "Failed to query PostgreSQL database ${dbname}: ${err_msg}"
    rm -f "${error_file}"
    return 1
  fi

  rm -f "${error_file}"
  if [ ! -s "${count_file}" ]; then
    error "Database query returned no results for PostgreSQL database ${dbname}"
    return 1
  fi
}

# Count database objects based on database type
function countDatabaseObjects() {
  local instance="$1"
  local count_file="$2"

  getDbConfig "${instance}" || return 1

  # Determine the correct Docker container based on database host
  local docker_host
  case "${dbhost}" in
    "jbt-mysql")
      docker_host="jbt-mysql"
      countMySQLObjects "${docker_host}" "${dbname}" "${dbuser}" "${dbpass}" "${dbprefix}" "${count_file}"
      ;;
    "jbt-madb"|"mariadb")
      docker_host="jbt-madb"
      countMySQLObjects "${docker_host}" "${dbname}" "${dbuser}" "${dbpass}" "${dbprefix}" "${count_file}"
      ;;
    "jbt-pg"|"postgres"|"postgresql")
      countPostgreSQLObjects "${dbname}" "${dbuser}" "${dbpass}" "${dbprefix}" "${count_file}"
      ;;
    *)
      error "Unsupported or unknown database host: ${dbhost}"
      return 1
      ;;
  esac
}

# Compare database counts and report changes
function reportDatabaseChanges() {
  local instance="$1"
  local before_file="$2"
  local after_file="$3"

  if [ ! -f "${before_file}" ] || [ ! -f "${after_file}" ]; then
    warning "Database count files not found, skipping comparison"
    return 0
  fi

  # Use diff to compare and capture output
  local diff_output
  diff_output=$(diff "${before_file}" "${after_file}" 2>&1 || true)

  if [ -n "${diff_output}" ]; then
    warning "jbt-${instance} – Database object changes detected:"
    cat <<< "${diff_output}"
  else
    log "jbt-${instance} – Number of database objects unchanged"
  fi
}

# Main function to count database objects before System Tests
# Usage: db_count_file=$(countBeforeTest <instance>)
function countBeforeTest() {
  local instance="$1"
  local count_dir="${JBT_TMP_FILE}.db-count"
  if ! mkdir -p "${count_dir}"; then
    error "Failed to create database count directory ${count_dir}"
    return 1
  fi

  local before_file="${count_dir}/jbt-${instance}-before.txt"
  if countDatabaseObjects "${instance}" "${before_file}"; then
    log "jbt-${instance} – Database objects counted before System Test" >&2
    echo "${before_file}"
    return 0
  else
    warning "jbt-${instance} – Failed to count database objects"
    return 1
  fi
}

# Compare database objects after System Tests and report changes
# Usage: countAfterTest <instance> <before_file>
function countAfterTest() {
  local instance="$1"
  local before_file="$2"

  if [ -z "${before_file}" ]; then
    return 0
  fi

  local after_file="${before_file/before/after}"
  if countDatabaseObjects "${instance}" "${after_file}"; then
    log "jbt-${instance} – Database objects counted after System Test" >&2
    reportDatabaseChanges "${instance}" "${before_file}" "${after_file}"
    return 0
  else
    warning "jbt-${instance} – Failed to count database objects after test"
    return 1
  fi
}
