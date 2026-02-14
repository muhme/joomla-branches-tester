#!/bin/bash
#
# helper.sh - General-purpose helper functions for various tasks across all bash scripts.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2026 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    echo "No, no, no. The script '$0' should only be sourced. cu :)"
    exit 1
fi

# Record the start time in seconds since 1.1.1970
start_time=$(date +%s)

# ${JBT_TMP_FILE} file can be used in the scripts without any worries
JBT_TMP_FILE=/tmp/$(basename "$0").$$
trap 'rm -rf $JBT_TMP_FILE' 0

# Cypress version 15.7.1 now contains Firefox on ARM images
# Cypress version 15.10.0 contains Cypress.expose()
declare -r \
  JBT_INSTALLATION_CYPRESS_VERSION="15.10.0"

# The following five arrays are positionally mapped, avoiding associative arrays
# to ensure compatibility with macOS default Bash 3.2.
#
# Database Unix socket paths into the '/var/run' directory
declare -r \
  JBT_S_MY="mysql-socket/mysqld.sock" \
  JBT_S_MA="mariadb-socket/mysqld.sock" \
  JBT_S_PG="postgresql-socket"
#
# Database and driver variants available for 'dbtype' in 'configuration.php'.
declare -ar \
  JBT_DB_VARIANTS=("mysqli" "mysql" "mariadbi" "mariadb" "pgsql")
# Database driver mapping for the variants as in Web Installer 'database type'.
declare -ar \
  JBT_DB_TYPES=("MySQLi" "MySQL (PDO)" "MySQLi" "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants.
declare -ar \
  JBT_DB_HOSTS=("jbt-mysql" "jbt-mysql" "jbt-madb" "jbt-madb" "jbt-pg")
# Database port mapping for the variants.
declare -ar \
  JBT_DB_PORTS=("7011" "7011" "7012" "7012" "7013")
# Database Unix socket paths into the '/jbt/run' directory
declare -ar \
  JBT_DB_SOCKETS=("${JBT_S_MY}" "${JBT_S_MY}" "${JBT_S_MA}" "${JBT_S_MA}" "${JBT_S_PG}")

# Valid PHP versions.
# (not 5.6 - 7.3 as there are problems and for lowest supported Joomla 3.9.0 there is PHP 7.4 available and working)
# TODO: 20 Nov 2025 to be changed once PHP 8.5 is released
declare -ar \
  JBT_VALID_PHP_VERSIONS=("php7.4" "php8.0" "php8.1" "php8.2" "php8.3" "php8.4" "php8.5" "highest")

# The highest PHP version usable for Joomla major-minor version (the two arrays correspond via the index).
# If a new Joomla version is created and not existing in this list, default is used in dockerImageName().
declare -ar \
  JBT_JOOMLA_VERSIONS=("39" "310" "40" "41" "42" "43" "44" "50" "51" "52" "53" "54" "60" "61") \
  JBT_PHP_VERSIONS=("7.4" "8.0" "8.0" "8.0" "8.1" "8.2" "8.2" "8.2" "8.3" "8.3" "8.4" "8.4" "8.4" "8.4")

# Base Docker containers (without the Joomla web server containers), eg
# ("jbt-pga" "jbt-mya" "jbt-mysql" "jbt-madb" "jbt-pg" "jbt-relay" "jbt-mail" "jbt-cypress" "jbt-novnc")
# Filled im the end.
declare -a \
  JBT_BASE_CONTAINERS=()
  while read -r line; do
    JBT_BASE_CONTAINERS+=("$line")
  done < <(grep 'container_name:' 'configs/docker-compose.base.yml' | awk '{print $2}')

# If the 'unpatched' option is not set and no patch is provided, use the following list:
# As of early October 2024, the main functionality is now working without the need for patches as before.
# shellcheck disable=SC2034 # It is used by other scripts after sourcing
declare -a \
  JBT_DEFAULT_PATCHES=("unpatched")

# Determine all Joomla usable version tags.
# Joomla version >= 3.9, as Joomla Docker images <= 3.8 cannot run 'apt-get update'.
# These are > 300 tags, e.g. ("3.9.0 3.9.0-alpha" ... "5.3.1-rc1" "5.4.0-alpha1" "6.0.0-alpha1")
# They are at least 4 chars (e.g. '1.7.3'), not using 'deprecate_eval', '11.2' etc.
declare -a \
  JBT_ALL_USABLE_TAGS=()
  # get tags | remove dereferenced annotated tag '^{}' lines | \
  #            remove commit hash and 'refs/tags/' in the lines | only 1-9.* | version sort | replace new line with space
  # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
  read -a JBT_ALL_USABLE_TAGS <<< "$(git ls-remote --tags https://github.com/joomla/joomla-cms | grep -v '\^{}' | \
                      sed 's/.*\///' | grep '^[1-9]\.' | sort -V | awk -F. '$1 > 3 || ($1 == 3 && $2 >= 9)' | tr '\n' ' ')"

# All currently used Joomla branches.
# eg. ("4.4-dev" "5.3-dev" "5.4-de"v "6.0-dev").
# We are using default, active and stale branches.
# With ugly screen-scraping, because no git command found and GitHub API with token looks too oversized.
# If we are offline, it returns an empty list!
declare -a \
  JBT_ALL_USED_BRANCHES=()
  # Get the JSON data from both the main branches and stale branches URLs
  json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches")
  stale_json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches/stale")
  # Extract the names of the branches, only with grep and sed, so as not to install any dependencies, e.g. jq
  # Use sed with -E flag to enable extended regular expressions, which is also working with macOS sed.
  branches=$(echo "$json_data" "$stale_json_data" | grep -o '"name":"[0-9]\+\.[0-9]\+-dev"' |
              sed -E 's/"name":"([0-9]+\.[0-9]+-dev)"/\1/')
  # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
  read -a JBT_ALL_USED_BRANCHES <<< "$(echo "${branches}" | tr ' ' '\n' | sort -n | tr '\n' ' ')"

# All highest minor tags, e.g. "3.9.28 3.10.12 4.0.6 ... 5.3.1 5.4.0-alpha1 6.0.0-alpha1"
# Skip pre-releases like -rc, -alpha or -beta if final release exist
declare -a \
  JBT_HIGHEST_MINOR_TAGS=()
  all_minor_versions=()
  for tag in "${JBT_ALL_USABLE_TAGS[@]}"; do
    minor=$(echo "$tag" | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
    [[ -n "$minor" ]] && all_minor_versions+=("$minor")
  done
  # shellcheck disable=SC2207 # There are no spaces in versions for deduplicate and sort
  all_minor_versions=($(printf '%s\n' "${all_minor_versions[@]}" | sort -u -V))
  # Find best tag per minor
  for minor in "${all_minor_versions[@]}"; do
    matches=()
    for tag in "${JBT_ALL_USABLE_TAGS[@]}"; do
      [[ "$tag" == "$minor."* ]] && matches+=("$tag")
    done
    stable=()
    for tag in "${matches[@]}"; do
      case "$tag" in
        *-alpha*|*-beta*|*-rc*) ;;  # skip pre-releases
        *) stable+=("$tag") ;;
      esac
    done
    if [[ ${#stable[@]} -gt 0 ]]; then
      best=$(printf '%s\n' "${stable[@]}" | sort -V | tail -n1)
    else
      best=$(printf '%s\n' "${matches[@]}" | sort -V | tail -n1)
    fi
    # npm ci in 5.0.3 and in 5.3.4 meantime has the problem:
    # ENOENT: no such file or directory, stat '/var/www/html/libraries/vendor/maximebf/debugbar/src/DebugBar/Resources
    if [[ "${best}" == "5.0.3" ]]; then
      # Simple use working 5.0.2
      best="5.0.2"
    fi
    if [[ "${best}" == "5.3.4" ]]; then
      # Simple use working 5.3.3
      best="5.3.3"
    fi
    JBT_HIGHEST_MINOR_TAGS+=("${best}")
  done

# Get all newest Joomla major.minor branch or patch versions.
# e.g. ("3.9.28" "3.10.12" "4.0.6" "4.1.5" "4.2.9" "4.3.4" "4.4-dev" "5.0.3" "5.1.4" "5.2.6" "5.3-dev" "5.4-dev" "6.0-dev" "6.1-dev")
#
declare -a \
  JBT_HIGHEST_VERSION=()
  # Get branch list: "4.4-dev" → key="4.4", value="4.4-dev"
  for branch in "${JBT_ALL_USED_BRANCHES[@]}"; do
    minor="${branch%-dev}"  # remove '-dev' suffix → "4.4-dev" → "4.4"
    branch_keys+=("${minor}")
    branch_values+=("${branch}")
  done
  for version in "${JBT_HIGHEST_MINOR_TAGS[@]}"; do
    minor=$(echo "${version}" | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
    # Check if minor exists in branch_keys
    found=false
    for ((i=0; i<${#branch_keys[@]}; i++)); do
      if [[ "${branch_keys[i]}" == "${minor}" ]]; then
        JBT_HIGHEST_VERSION+=("${branch_values[i]}")
        found=true
        break
      fi
    done
    # Fallback to the tag version if no branch override
    if [[ "${found}" == false ]]; then
      JBT_HIGHEST_VERSION+=("${version}")
    fi
  done
  # Final we have to check if we have a new branch without any tag so far
  for branch in "${JBT_ALL_USED_BRANCHES[@]}"; do
    # Check if branch exists already
    found=false
    for version in "${JBT_HIGHEST_VERSION[@]}"; do
      if [[ "${version}" == "${branch}" ]]; then
        found=true
        break
      fi
    done
    if [[ "${found}" == false ]]; then
      JBT_HIGHEST_VERSION+=("${branch}")
    fi
  done

# List installed Joomla versions from 'joomla-*' directories.
# Returns space separated sorted string, e.g. "39 310 40 41 42 43 44 51 52 53 60"
#
getAllInstalledInstances() {
  local instance instances=() sorted_instances=() final_instances=()
  # Loop over directories that match the pattern joomla-*
  for dir in joomla-*; do
      # Check if it's a directory and extract the version part
      if [[ -d "$dir" ]]; then
          instance="${dir#joomla-}"
          # e.g."39" -> "309"
          [[ ${#instance} -eq 2 ]] && instance="${instance:0:1}0${instance:1:1}"
          instances+=("$instance")
      fi
  done

  # Sort the instances, e.g. 309 310 400 ...
  # shellcheck disable=SC2162,SC2068
  read -a sorted_instances <<< "$(printf '%s\n' ${instances[@]} | sort -k1,1n -k2,2n | tr '\n' ' ')"

  # Remove the centre inserted zero
  # shellcheck disable=SC2068 # Intentionally using individual array elements
  for instance in ${sorted_instances[@]}; do
      # Check if the instance has three digits with '0' as the middle digit
      if [[ $instance == ?0? ]]; then
          final_instances+=("${instance:0:1}${instance:2:1}")
      else
          final_instances+=("$instance")
      fi
  done

  echo "${final_instances[*]}"
}

# Check if the given argument is a Joomla used branch, tag version or valid major minor.
# e.g. isValidVersion "310" -> 0
# e.g. isValidVersion "44" -> 0
# e.g. isValidVersion "5.2-0-alpha3" -> 0
#
function isValidVersion() {
  local version="$1" fullVersion branch versions=()

  if [ -z "$1" ]; then
    return 1 # Not a valid version
  fi

  # shellcheck disable=SC2178,2006 # There are no spaces in branches, not doing sub-shell with $() to have global array set
  for branch in "${JBT_ALL_USED_BRANCHES[@]}"; do
    # 1. Full branch name? e.g. 5.3-dev
    if [[ "${branch}" == "${version}" ]]; then
      return 0 # success
    fi
    # 2. Abbreviated branch name? e.g. "60"
    if [[ `echo "{$branch}" | sed -E 's/([0-9])\.([0-9]+)-dev/\1\2/g'` == "${version}" ]]; then
      return 0 # success
    fi
  done

  # shellcheck disable=SC2178,2006 # There are no spaces in tags and not doing sub-shell with $() to have global array set
  for tag in "${JBT_ALL_USABLE_TAGS[@]}"; do
    # 3. Full Tag name? e.g. "5.2.0"
    if [[ "${tag}" == "${version}" ]]; then
      return 0 # success
    fi
  done

  # 4. Joomla major-minor? e.g. "310"
  for tag in "${JBT_JOOMLA_VERSIONS[@]}"; do
    if [[ "${tag}" == "${version}" || "${tag}" == "${fullVersion}" ]]; then
      return 0 # success
    fi
  done

  # Already installed? e.g. 4.3.0 as joomla-43
  if [ -d "joomla-${version}" ]; then
    return 0 # success
  fi

  return 1 # Not a valid version
}

# Check if the given argument is a valid PHP version.
# e.g. isValidPHP "php7.4" -> 1
#
function isValidPHP() {
  local php_version="$1"

  if [ "${php_version}" = "highest" ]; then
    return 0 # is valid
  fi
  for p in "${JBT_VALID_PHP_VERSIONS[@]}"; do
    if [ "$p" = "$php_version" ]; then
      return 0 # is valid
    fi
  done
  return 1 # not valid
}

# Returns the full Git branch or tag name corresponding for the major minor.
# If an major minor is given without branch, the highest tag is used.
# Returns on space separated string, e.g.:
#   "5.4.0-alpha1" -> "5.4.0-alpha1"
#   "52"           -> "5.2.6"
#   "310"          -> "3.10.12"
#   "60"           -> "6.0-dev"
#
function fullName() {
  local name="$1" tag full_name branch

  if [[ -z "${name}" ]]; then
    error "fullName(): missing version"
    return
  fi

  # 1. It is already a tag name
  for tag in "${JBT_ALL_USABLE_TAGS[@]}"; do
    if [[ "${name}" == "${tag}" ]]; then
      echo "${name}"
      return
    fi
  done

  # 2. Current branch abbreviation, eg. "60" -> branch "6.0-dev"
  if [[ "$name" =~ ^[0-9]{2}$ ]]; then
    # Two digits branch? e.g. "44" -> "4.4-dev"
    full_name="$(echo "$name" | sed -E 's/([0-9])([0-9])/\1.\2-dev/')"
    for branch in "${JBT_ALL_USED_BRANCHES[@]}"; do
      if [[ "${branch}" == "${full_name}" ]]; then
        echo "${full_name}"
        return
      fi
    done
  fi

  # 3. major minor, e.g. "310" -> highest tag "3.10.12"
  for tag in "${JBT_HIGHEST_MINOR_TAGS[@]}"; do
    major_minor=$(echo "$tag" | sed -E 's/^([0-9]+)\.([0-9]+)\..*/\1\2/')
    if [[ "${major_minor}" = "${name}" ]]; then
      echo "${tag}"
      return
    fi
  done

  # 4. Take the orignal, e.g. "5.3.1"
  echo "${name}"
}

# Returns major and minor number from version, used as instance label.
# e.g. getMajorMinor "5.2.0-beta3" -> '52'
# e.g. getMajorMinor "4.4" "pad" -> '044'
# e.g. getMajorMinor "3.10" "pad" -> '310'
#
function getMajorMinor() {
  if [[ -z "$1" ]]; then
    error "getMajorMinor(): missing version"
    return 1
  else
    major_minor=$(echo "${1}" | sed -E 's/^([0-9]+)\.([0-9]+).*/\1\2/')
    # Add leading zero if only two digits and the second argument is "pad"
    if [[ "${#major_minor}" -eq 2 && "$2" == "pad" ]]; then
      echo "0${major_minor}"
    else
      echo "${major_minor}"
    fi
  fi
}

# Returns the database type for a given database variant.
# e.g. dbTypeForVariant "mysql" -> "MySQL (PDO)"
#
function dbTypeForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "${JBT_DB_TYPES[$i]}"
      return
    fi
  done
  error "No database type found for '$1' database variant."
}

# Returns the database host for a given database variant.
# e.g. dbHostForVariant "mysql" -> "jbt-mysql"
#
function dbHostForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "${JBT_DB_HOSTS[$i]}"
      return
    fi
  done
  error "No database host found for '$1' database variant."
}

# Returns the database Unix socket path for a given database variant.
# e.g. dbSocketForVariant "mysql" -> "unix:/var/run/mysql-socket/mysqld.sock"
#
function dbSocketForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "unix:/var/run/${JBT_DB_SOCKETS[$i]}"
      return
    fi
  done
  error "No database Unix socket found for '$1' database variant."
}

# Returns the host.docker.internal mapped database port for a given database variant.
# e.g. dbPortForVariant "mysql" -> "7011"
#
function dbPortForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "${JBT_DB_PORTS[$i]}"
      return
    fi
  done
  error "No database port found for '$1' database variant."
}

# Check if the given argument is a valid database variant.
# e.g. isValidVariant "Ingres" -> 1
#
function isValidVariant() {
  local variant="$1"
  for v in "${JBT_DB_VARIANTS[@]}"; do
    if [[ "$v" == "$variant" ]]; then
      return 0 # success
    fi
  done
  return 1 # nope
}

# Adjust 'configuration.php' for JBT, e.g. set 'tEstValue' as the secret.
# As Joomla System Tests do in 'tests/System/integration/install/Installation.cy.js'.
# Also use the 'filesystem' session handler from 4.0 upwards.
# Required after running
#   - JBT's Joomla installation,
#   - joomla-cypress Joomla installation tests or
#   - system tests in using install/Installation.cy.js (where smtpport is overwritten)
#
function adjustJoomlaConfigurationForJBT() {
  local instance="$1"

  if [ -f "joomla-${instance}/configuration.php" ]; then
    if ! grep -q 'tEstValue' "joomla-${instance}/configuration.php" || \
       ! grep -q 'smtpport = 7025' "joomla-${instance}/configuration.php"; then

      log "jbt-${instance} – Adopt configuration.php for JBT"

      # Session handler 'filesystem' is avaialable since 4.0
      session_handler="database"
      if (( instance != 310 && instance >= 40 )); then
        # Using 'filesystem' as the session handler to prevent logging in again after a few minutes,
        # for whatever reason this differs from default 'database'.
        session_handler="filesystem"
      fi
      # Since we get an access error when changing the ownership, even as root user,
      # we create configuration.php.new and rename it.
      docker exec "jbt-${instance}" bash -c "sed \
        -e \"s|\(public .secret =\).*|\1 'tEstValue';|\" \
        -e \"s|\(public .mailonline =\).*|\1 true;|\" \
        -e \"s|\(public .mailer =\).*|\1 'smtp';|\" \
        -e \"s|\(public .smtphost =\).*|\1 'host.docker.internal';|\" \
        -e \"s|\(public .smtpport =\).*|\1 7025;|\" \
        -e \"s|\(public .session_handler =\).*|\1 '${session_handler}';|\" \
        configuration.php > configuration.php.new && \
        mv configuration.php.new configuration.php && \
        chown www-data:www-data configuration.php && \
        chmod 0444 configuration.php"
    fi
  else
    log "jbt-${instance} – There is no file 'joomla-${instance}/configuration.php'"
    # Next step should be Joomla installation
  fi
}

# Deletes a service entry in a Docker compose file.
# Silently ignores if the service does not exist.
# 1st argument is service name, e.g. "5.4-dev"
# 2nd argument is composer file name
#
deleteService() {
  local svc="$1" file="$2"

  awk -v svc="$svc" '
    BEGIN { del = 0 }
    $0 ~ "^  " svc ":[[:space:]]*$" { del = 1; next }
    del && $0 ~ /^(  [^[:space:]]+:[[:space:]]*$|[^[:space:]])/ { del = 0 }
    !del
  ' "${file}" > "${JBT_TMP_FILE}" || {
    error "${svc} – delete_service(): awk failed!"
    exit 1
  }
  mv "${JBT_TMP_FILE}" "${file}" || {
    error "${svc} – delete_service(): mv failed!"
    exit 1
  }
}

# Append a web server entry to Docker compose file, if not already existing
# 1st argument is e.g. "5.2-dev" or "4.4.1-alpha4"
# 2nd argument is PHP version, e.g. "php8.5" or "highest"
# 3rd argument is Docker compose file name
#
function appendWebServer() {
  local version="$1" php_version="$2" file="$3" instance https_port_digits din padded
  instance=$(getMajorMinor "${version}")
  https_port_digits=$(( instance + 100 ))
  din=$(dockerImageName "${version}" "${php_version}")
  padded=$(getMajorMinor "${version}" "pad")

  if grep -q "^  jbt-${instance}" "${file}"; then
    log "jbt-${instance} – An entry already exists in Docker compose; leave it unmodified"
  else
    # Add Joomla web server entry.
    # - UUU - HTTPS port number last three digits
    # - VVV - IPv4 address fourth octed
    # - WWW - IPv4 adress third octed
    # - XXX - IPv6 address last hextet, Docker image jbt-number and joomla-number directory name
    # - YYY - Docker image name
    # - ZZZ - HTTP port number last three digits
    #   e.g. 5.2.9   -> 152 for UUU, 52 for VVV, 0 for WWW,  52 for XXX, 052 for ZZZ and 5 for YYY
    #   e.g. 3.10.12 -> 410 for UUU, 10 for VVV, 3 for WWW, 310 for XXX, 310 for ZZZ and 3 for YYY
    log "jbt-${instance} – Adding a Docker compose entry using the '${din}' image"
    sed -e '/^#/d' \
        -e "s/UUU/${https_port_digits}/" \
        -e "s/VVV/${padded: -2}/" \
        -e "s/WWW/${padded:0:1}/" \
        -e "s/XXX/${instance}/" \
        -e "s/YYY/${din}/" \
        -e "s/ZZZ/${padded}/" 'configs/docker-compose.joomla.yml' >> "${file}"
  fi
}

# Create 'docker-compose.yml' file with one or multiple web servers.
# 1st argument is e.g. "5.2-dev" or "4.4.1-alpha4 5.1.0"
# 2nd argument e.g. "php8.5" or "highest"
# 3rd optional argument is "recreate", which replaces or inserts the web server container.
#
function createDockerComposeFile() {
  local php_version="$2" working="$3" instance

  # Declare all local variables to prevent SC2155 - Declare and assign separately to avoid masking return values.
  local version versions=() din
  # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
  read -a versions <<< "$(echo "$1" | tr ' ' '\n' | sort -n | tr '\n' ' ')"

  if [ "${working}" = "recreate" ]; then
    # Cut named volumes, they are added always in the end.
    csplit 'docker-compose.yml' '/^volumes:/'
    for version in "${versions[@]}"; do
      instance=$(getMajorMinor "${version}")
      deleteService "jbt-${instance}" "xx00"
      appendWebServer "${version}" "${php_version}" xx00
    done
    cat xx00 xx01 > docker-compose.yml && rm xx00 xx01
  else
    sed -e "s/JBT_INSTALLATION_CYPRESS_VERSION/${JBT_INSTALLATION_CYPRESS_VERSION}/" \
           'configs/docker-compose.base.yml'  > 'docker-compose.yml'
    for version in "${versions[@]}"; do
      appendWebServer "${version}" "${php_version}" 'docker-compose.yml'
    done

    # Add named volumes definition.
    sed -e '/^#/d' 'configs/docker-compose.end.yml' >> 'docker-compose.yml'
  fi

}

# Returns existing Docker image name for given Joomla and PHP version.
#   e.g. dockerImageName "4.4-dev" "php8.1" -> "php:8.1-apache"
#   e.g. dockerImageName "3.9" "highest" -> "php:7.4-apache"
#   exceptions/restrictions:
#   - Docker images starting with Joomla 3.4 (but as with not working npm we start with >= 3.9)
#
function dockerImageName() {
  local instance php_to_use php_version="$2"
  instance=$(getMajorMinor "$1")

  if [ -z "${php_version}" ] || [ "${php_version}" = "highest" ]; then
    for i in "${!JBT_JOOMLA_VERSIONS[@]}"; do
      if [ "${JBT_JOOMLA_VERSIONS[$i]}" = "${instance}" ]; then
        php_to_use="php:${JBT_PHP_VERSIONS[$i]}"
      fi
    done
    if [ -z "${php_to_use}" ]; then
      # Oops Joomla version not found, new release? Use default:
      php_to_use="php:8.4"
    fi
  else
    # e.g. from "php8.1" to "php:8.1"
    php_to_use="php:${php_version#php}"
  fi

  echo "${php_to_use}-apache"
}

# Force recreate Docker image if a newer version is pulled (e.g. for PHP8.5-rc or pgadmin)
#   e.g. updateContainerNeeded 54 php:8.4-apache jbt-54
#   e.g. updateContainerNeeded 54 dpage/pgadmin4:latest pgadmin
#
function recreateContainersWhenNecessary() {
  local instance="$1" din="$2" service="$3" old_digest new_digest

  # Get currently cached digest (if any)
  old_digest="$(docker image inspect --format='{{index .RepoDigests 0}}' "${din}" 2>/dev/null || true)"

  log "jbt-${instance} – Pulling ${din} (manual prepare update)"
  docker pull "${din}"

  # Get digest after pull
  new_digest="$(docker image inspect --format='{{index .RepoDigests 0}}' "${din}" 2>/dev/null || true)"

  if [ -z "$new_digest" ]; then
    error "jbt-${instance} – ERROR: image '${din}' not present after pull"
    exit 1
  fi

  log "jbt-${instance} – Starting Docker container"

  if [ "${old_digest}" = "${new_digest}" ]; then
    log "jbt-${instance} – Image '${din}' unchanged; skipping recreate"
    docker compose up -d "${service}"
  else
    log "jbt-${instance} – Image '${din}' changed; recreating container"
    docker compose up -d --no-deps --force-recreate --remove-orphans --wait "${service}"
  fi
}

# Retrieve the installed Joomla major and minor version from the `libraries/src/Version.php` file in the specified branch directory.
# e.g. getJoomlaVersion "joomla-51" -> "51"
#
function getJoomlaVersion() {
  local versions_file="$1/libraries/src/Version.php"

  if [ ! -f "$versions_file" ]; then
    error "There is no file \"${versions_file}\"."
  fi

  # from file content:
  #     public const MAJOR_VERSION = 5;
  #     public const MINOR_VERSION = 1;
  version=$(grep -E 'const MAJOR_VERSION|const MINOR_VERSION' "$versions_file" | sed -e 's/.*= //' | tr -d ';\n')

  # Two digits?
  if [[ ! $version =~ ^[0-9]{2}$ ]]; then
    error "Could not find Joomla major and minor number in file \"${versions_file}\"."
  fi

  echo "$version"
}

# Check if a test name is valid.
# e.g. isValidTestName "system" "php-cs-fixer" "phpcs" "system"
#
isValidTestName() {
  local test="$1"
  shift                  # First argument is eaten as the test name
  local all_tests=("$@") # Remaining arguments are the ALL_TESTS array

  for valid_test in "${all_tests[@]}"; do
    if [[ "$test" == "$valid_test" ]]; then
      return 0 # Yes, test name is valid
    fi
  done
  return 1 # No
}

# The Cypress custom command installJoomlaMultilingualSite() deletes the Joomla installation folder.
# Restore the saved installation folder and set ownership to www-data:www-data.
#
restoreInstallationFolder() {
  local instance="$1"

  if [ ! -d "joomla-${instance}/installation" ]; then
    if [ -d "installation/joomla-${instance}/installation" ]; then
      log "jbt-${instance} – Restoring 'joomla-${instance}/installation' directory"
      cp -r "installation/joomla-${instance}/installation" "joomla-${instance}/installation" 2>/dev/null ||
        sudo cp -r "installation/joomla-${instance}/installation" "joomla-${instance}/installation"
      if [ -f "joomla-${instance}/package.json" ]; then
        log "jbt-${instance} – Running npm clean install"
        docker exec "jbt-${instance}" bash -c 'cd /var/www/html && npm ci'
      fi
      # Restored files are owned by root and next time installJoomlaMultilingualSite() will fail deleting them.
      docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true &' &
    else
      error "jbt-${instance} – Missing 'joomla-${instance}/installation' directory"
      # Proceed in the hope that it will not be needed
    fi
  fi
}

# Return script running time e.g. as "17 seconds" or as "3:18".
#
runningTime() {
  # Record the actual time in seconds since 1.1.1970
  actual_time=$(date +%s)

  # Calculate the elapsed time in minutes and seconds
  elapsed_time=$((actual_time - start_time))
  minutes=$((elapsed_time / 60))
  seconds=$((elapsed_time % 60))

  # Having seconds also formatted with a leading zero
  formatted_seconds=$(printf "%02d" $seconds)

  # Human readable output
  if [ $minutes -gt 0 ]; then
    echo "${minutes}:${formatted_seconds}"
  else
    if [ $seconds -eq 1 ]; then
      echo "1 second"
    else
      echo "${seconds} seconds"
    fi
  fi
}

# Get random quote from api.zitat-service.de like Joomla module 'zitat-servive.de'
# https://extensions.joomla.org/extension/news-display/quotes/zitat-service-de/
#
# Sample with author and one more without:
# A day without a smile is a wasted day. Charlie Chaplin
# Shoot for the moon. Even if you miss, you'll land among the stars.
#
# Can be disable by env var JBT_SHOW_QUOTE=false
#
function random_quote() {

  if [ "${JBT_SHOW_QUOTE}" = "false" ] || [ "${JBT_SHOW_QUOTE}" = "0" ]; then
    return 0
  fi

  # Check the LANG environment variable
  lang_code=$(echo "$LANG" | cut -c1-2 | tr '[:upper:]' '[:lower:]')

  # Use one of the supported languages or default to English
  case "$lang_code" in
  de | es | ja | uk)
    language=$lang_code
    ;;
  *)
    language="en"
    ;;
  esac

  # Fetch JSON from the quote API
  json=$(curl -s "https://api.zitat-service.de/v1/quote?language=${language}")

  # Extract the quote
  # Sometimes \r and \n are included and deleted respective replaced
  quote=$(echo "$json" | sed -n 's/.*"quote":"\([^"]*\)".*/\1/p' | sed 's/\\r//g' | sed 's/\\n/ /g')

  # Extract the author's name
  author=$(echo "$json" | sed -n 's/.*"authorName":"\([^"]*\)".*/\1/p')
  authorID=$(echo "$json" | sed -n 's/.*"authorId":\([0-9]*\).*/\1/p')

  # If we are offline, we have no quote :(
  if [ "${quote}" != "" ]; then
    # Print the author only if it's not "Unknown" with authorID 0
    if [ "$authorID" != "0" ]; then
      printf "\\n    \"%s\", %s\\n \\n" "${quote}" "${author}"
    else
      printf "\\n    \"%s\"\\n \\n" "${quote}"
    fi
  fi
}

# Use ANSI escape sequences to colorize JBT log messages to differentiate them from others.
#
JBT_UNDERLINE="\033[4m"
JBT_GREEN_BG="\033[42m"
JBT_ORANGE="\033[38;5;208m"
JBT_RED="\033[0;31m"
JBT_BOLD="\033[1m"
JBT_RESET="\033[0m"

# Is the 'NO_COLOR' environment variable set and non-empty?
if [ -n "${NO_COLOR:-}" ]; then
  # Do not use color for log messages.
  JBT_UNDERLINE=""
  JBT_GREEN_BG=""
  JBT_ORANGE=""
  JBT_RED=""
  JBT_BOLD=""
  JBT_RESET=""
fi

# Log message with date and time in bold and green background on stdout.
#
# If '>>>' or '<<<' is provided as the first argument, it will replace second '***'' marker.
# The remaining arguments are treated as the log message.
#
log() {
  # Default second marker is '***''.
  local marker='***'
  # Check if the first argument is the starting or the ending marker.
  if [[ "$1" == '>>>' || "$1" == '<<<' ]]; then
    marker="$1"
    shift  # Argument is eaten as marker.
  fi

  # -e enables backslash escapes
  echo -e "${JBT_GREEN_BG}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') ${marker} $*${JBT_RESET}"
}

# Warning message with date and time in bold and orange on stderr.
#
warning() {
  # -e enables backslash escapes
  echo -e "${JBT_ORANGE}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') WRN $*${JBT_RESET}" >&2
}

# Error message with date and time in bold and dark red on stderr.
#
# If '<<<' is provided as the first argument, it will replace second '***'' marker.
# The remaining arguments are treated as the log message.
#
error() {
  # Default second marker is '***''.
  local marker='ERR'
  # Check if the first argument is the the ending marker.
  if [[ "$1" == '<<<' ]]; then
    marker="$1"
    shift  # Argument is eaten as marker.
  fi

  # -e enables backslash escapes
  echo -e "${JBT_RED}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') ${marker} $*${JBT_RESET}" >&2
}

# Output in bold and underlined.
#
header() {
  echo -e "${JBT_UNDERLINE}${JBT_BOLD}$*${JBT_RESET}"
}

# Output in red.
#
red() {
  echo -e "${JBT_RED}$*${JBT_RESET}"
}

# With -e set, the script exits immediately on command failure.
# Show a red error message with the script name and line number.
#
errorHandler() {
  error "An error occurred, probably in script '$(basename "$0")' in line $1."
  error '<<<' "Script '$(basename "$0")' failed after $(runningTime)."
  trap - EXIT
  exit 1
}
trap 'errorHandler $LINENO' ERR

# This is the end.
#
theEnd() {
  if [ $? -ne 0 ]; then
    error "'$0' failed after $(runningTime)."
  else
    log "<<<" "'$0' finished in $(runningTime)"
  fi
}
trap theEnd EXIT

# No, every end is a new beginning :)
#
log ">>>" "'$0${*:+ $*}' started"

# Instance is JBT version < 2.0.0 created and we are not running 'scripts/clean'?
if [ -f "docker-compose.yml" ] && [ "$0" != "scripts/clean.sh" ] && grep -q "jbt_cypress" "docker-compose.yml"; then
    error "Installation < 2.0.0 found, hostnames changed. You need first to run 'scripts/create'."
    # Give only warning, don't stop as we may running 'scripts/create'
elif find . -maxdepth 1 -type d -name "branch_*" | grep -q . && [ "$0" != "scripts/clean.sh" ]; then
    # Instance is JBT version < 2.0.8. created and we are not running 'scripts/clean'
    error "Installation < 2.0.8 found, branch directory names changed. You need first to run 'scripts/create'."
    # Give only warning, don't stop as we may running 'scripts/create'
fi
