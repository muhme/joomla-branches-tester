#!/bin/bash
#
# helper.sh - General-purpose helper functions for various tasks across all bash scripts.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    echo "No, no, no. The script '$0' should only be sourced. cu :)"
    exit 1
fi

# Record the start time in seconds since 1.1.1970
start_time=$(date +%s)

# ${TMP} file can be used in the scripts without any worries
TMP=/tmp/$(basename $0).$$
trap 'rm -rf $TMP' 0

# The following four arrays are positionally mapped, avoiding associative arrays
# to ensure compatibility with macOS default Bash 3.2.
#
# Database Unix socket paths into the '/jbt/run' directory
JBT_S_MY="mysql-socket/mysqld.sock"
JBT_S_MA="mariadb-socket/mysqld.sock"
JBT_S_PG="postgresql-socket"
#
# Database and driver variants available for 'dbtype' in 'configuration.php'.
JBT_DB_VARIANTS=("mysqli" "mysql" "mariadbi" "mariadb" "pgsql")
# Database driver mapping for the variants as in Web Installer 'database type'.
JBT_DB_TYPES=("MySQLi" "MySQL (PDO)" "MySQLi" "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants.
JBT_DB_HOSTS=("jbt_mysql" "jbt_mysql" "jbt_madb" "jbt_madb" "jbt_pg")
# Database port mapping for the variants.
JBT_DB_PORTS=("7011" "7011" "7012" "7012" "7013")
# Database Unix socket paths into the '/jbt/run' directory
JBT_DB_SOCKETS=("${JBT_S_MY}" "${JBT_S_MY}" "${JBT_S_MA}" "${JBT_S_MA}" "${JBT_S_PG}")

# PHP versions to choose from, as Docker images with those versions are available.
JBT_PHP_VERSIONS=("php8.1" "php8.2" "php8.3")

# Base Docker containers, eg ("jbt_pga" "jbt_mya" "jbt_mysql" "jbt_madb" "jbt_pg" "jbt_relay" "jbt_mail" "jbt_cypress" "jbt_novnc")
JBT_BASE_CONTAINERS=()
while read -r line; do
  JBT_BASE_CONTAINERS+=("$line")
done < <(grep 'container_name:' docker-compose.base.yml | awk '{print $2}')

# Determine the currently used Joomla branches.
# e.g. getVersions -> "44 52 53 60"
#
# We are using default, active and stale branches.
# With ugly screen-scraping, because no git command found and GitHub API with token looks too oversized.
#
function getVersions() {

  # Get the JSON data from both the main branches and stale branches URLs
  local json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches")
  local stale_json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches/stale")

  # Extract the names of the branches, only with grep and sed, so as not to install any dependencies, e.g. jq
  # Use sed with -E flag to enable extended regular expressions, which is also working with macOS sed.
  local branches=$(echo "$json_data" "$stale_json_data" | grep -o '"name":"[0-9]\+\.[0-9]\+-dev"' |
    sed -E 's/"name":"([0-9]+)\.([0-9]+)-dev"/\1\2/')

  # Create as array and add branches from both sources
  local formatted_branches=()
  for branch in ${branches}; do
    formatted_branches+=("${branch}")
  done

  # Sort
  local sorted_branches=()
  IFS=$'\n' sorted_branches=($(sort <<<"${formatted_branches[*]}"))
  unset IFS

  # Are we offline? Set default branch versions with 42 as marker.
  if [ ${#sorted_branches[@]} -eq 0 ]; then
    echo "42 44 51 52 53 54 60"
  else
    echo "${sorted_branches[*]}"
  fi
}

# Check if the given argument is a valid Joomla version.
# e.g. isValidVersion "44" "44 51 52 60" -> 0
#
function isValidVersion() {
  local version="$1"
  local versions=()
  IFS=' ' read -r -a versions <<<"$2" # convert to array

  for v in "${versions[@]}"; do
    if [[ "$v" == "$version" ]]; then
      return 0 # success
    fi
  done
  return 1 # nope
}

# Check if the given argument is a valid PHP version.
# e.g. isValidVersion "php7.2" -> 1
#
function isValidPHP() {
  local php_version="$1"
  for p in "${JBT_PHP_VERSIONS[@]}"; do
    if [[ "$p" == "$php_version" ]]; then
      return 0 # success
    fi
  done
  return 1 # nope
}

# Returns the Git branch name corresponding to the version number.
# e.g. branchName "51" -> '5.1-dev'
#
function branchName() {
  if [[ -z "$1" ]]; then
    echo "missing version"
    return 1
  else
    echo "${1}" | sed -E 's/([0-9])([0-9])/\1.\2-dev/'
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
  error "No database type found for '$1' database variant"
}

# Returns the database host for a given database variant.
# e.g. dbHostForVariant "mysql" -> "jbt_mysql"
#
function dbHostForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "${JBT_DB_HOSTS[$i]}"
      return
    fi
  done
  error "No database host found for '$1' database variant"
}

# Returns the database Unix socket path for a given database variant.
# e.g. dbSocketForVariant "mysql" -> "unix:/jbt/run/mysql-socket/mysqld.sock"
#
function dbSocketForVariant() {
  local variant=$1
  for i in "${!JBT_DB_VARIANTS[@]}"; do
    if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
      echo "unix:/jbt/run/${JBT_DB_SOCKETS[$i]}"
      return
    fi
  done
  error "No database Unix socket found for '$1' database variant"
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
  error "No database port found for '$1' database variant"
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

# Create 'docker-compose.yml' file with one or multiple web servers.
# 1st argument is e.g. "52" or "44 51 52 53 60"
# 2nd argument e.g. "php8.1"
# 3rd argument is "IPv4" or "IPv6"
# 4th optional argument is "append", then the web server is added if it is not already existing
#
function createDockerComposeFile() {
  local php_version="$2"
  local network="$3"
  local working="$4"
  local versions=()
  IFS=' ' versions=($(sort <<<"$1"))
  unset IFS # map to array

  if [ "${working}" != "append" ]; then
    if [ "${network}" = "IPv4" ]; then
      cp docker-compose.base.yml docker-compose.yml
    else
      sed -e 's/enable_ipv6: false/enable_ipv6: true/' \
        -e 's/subnet: "192.168.150.0\/24"/subnet: "fd00::\/8"/' \
        docker-compose.base.yml >docker-compose.yml

    fi
  fi

  local version
  for version in "${versions[@]}"; do
    local din=$(dockerImageName "$version" "$php_version")
    local doit=true
    if [ "${working}" = "append" ]; then
      if grep -q "^  jbt_${version}" docker-compose.yml; then
        log "jbt_${version} – An entry already exists in 'docker-compose.base.yml'; leave it unmodified."
        doit=false
      else
        log "jbt_${version} – Adding an entry in 'docker-compose.base.yml'."
      fi
    fi
    if $doit; then
      sed -e '/^#/d' -e "s/XX/${version}/" -e "s/Y/${din}/" docker-compose.joomla.yml >>docker-compose.yml
    fi
  done
}

# Returns existing Docker image name for given Joomla and PHP version.
#   e.g. dockerImageName "44" "php8.1" -> "4.4-php8.1-apache"
#   exceptions:
#   - There is no "4.4-php8.3-apache", fallback "4.4-php8.2-apache"
#   - There are no Joomla 5.3 and 6.0 images fallback to Joomla 5.2
#
function dockerImageName() {
  local version="$1"
  local php_version="$2"

  # joomla:4 or joomla:5 image?
  if [ "$version" = "44" ]; then
    local php_to_use="$php_version"
    if [ "$php_version" = "php8.3" ]; then
      # There is no PHP 8.3 for Joomla 4.4, simple use PHP 8.2.
      php_to_use="php8.2"
    fi
    base="4.4-${php_to_use}"
  else
    # Currently (August 2024) there are no Joomla 5.3 and Joomla 6.0 Docker images,
    # simple use 5.2 as base.
    local version_to_use="$version"
    if [ "$version" -gt "52" ]; then
      version_to_use="52"
    fi
    # e.g. "5.2-php8.1-apache"
    base="${version_to_use:0:1}.${version_to_use:1}-${php_version}"
  fi
  echo "joomla:${base}-apache"
}

# Retrieve the installed Joomla major and minor version from the `libraries/src/Version.php` file in the specified branch directory.
# e.g. getJoomlaVersion "branch_51" -> "51"
#
function getJoomlaVersion() {
  local versions_file="$1/libraries/src/Version.php"

  if [ ! -f "$versions_file" ]; then
    error "There is no file \"${versions_file}\""
    exit 1
  fi

  # from file content:
  #     public const MAJOR_VERSION = 5;
  #     public const MINOR_VERSION = 1;
  version=$(grep -E 'const MAJOR_VERSION|const MINOR_VERSION' "$versions_file" | sed -e 's/.*= //' | tr -d ';\n')

  # Two digits?
  if [[ ! $version =~ ^[0-9]{2}$ ]]; then
    error "Could not find Joomla major and minor number in file \"${versions_file}\""
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

# Use ANSI escape sequences to colorize JBT log messages to differentiate them from others.
#
JBT_LIGHT_GREEN_BG="\033[102m"
JBT_GREEN_BG="\033[42m"
JBT_RED="\033[0;31m"
JBT_BOLD="\033[1m"
JBT_RESET="\033[0m"

# Is the 'NO_COLOR' environment variable set and non-empty?
if [ -n "${NO_COLOR}" ]; then
  # Do not use color for log messages.
  JBT_LIGHT_GREEN_BG=""
  JBT_GREEN_BG=""
  JBT_RED=""
  JBT_BOLD=""
  JBT_RESET=""
fi

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
function random_quote() {

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
      echo "\"${quote}\", ${author}"
    else
      echo "\"${quote}\""
    fi
  fi
}

# Log message with date and time in bold and green background on stdout.
#
log() {
  # -e enables backslash escapes
  echo -e "${JBT_GREEN_BG}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}"
}

# Error message with date and time in bold and dark red on stderr.
#
error() {
  # -e enables backslash escapes
  echo -e "${JBT_RED}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}" >&2
}

# With -e set, the script exits immediately on command failure.
# Show a red error message with the script name and line number.
#
errorHandler() {
  error "An error occurred, probably in script '$(basename "$0")' in line $1."
  error "Script '$(basename "$0")' failed after $(runningTime)."
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
    log "'$0' finished in $(runningTime)."
  fi
}
trap theEnd EXIT

# No, every end is a new beginning :)
#
log "'$0' started."
