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

# ${JBT_TMP_FILE} file can be used in the scripts without any worries
JBT_TMP_FILE=/tmp/$(basename "$0").$$
trap 'rm -rf $JBT_TMP_FILE' 0

# The following four arrays are positionally mapped, avoiding associative arrays
# to ensure compatibility with macOS default Bash 3.2.
#
# Database Unix socket paths into the '/var/run' directory
JBT_S_MY="mysql-socket/mysqld.sock"
JBT_S_MA="mariadb-socket/mysqld.sock"
JBT_S_PG="postgresql-socket"
#
# Database and driver variants available for 'dbtype' in 'configuration.php'.
JBT_DB_VARIANTS=("mysqli" "mysql" "mariadbi" "mariadb" "pgsql")
# Database driver mapping for the variants as in Web Installer 'database type'.
JBT_DB_TYPES=("MySQLi" "MySQL (PDO)" "MySQLi" "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants.
JBT_DB_HOSTS=("jbt-mysql" "jbt-mysql" "jbt-madb" "jbt-madb" "jbt-pg")
# Database port mapping for the variants.
JBT_DB_PORTS=("7011" "7011" "7012" "7012" "7013")
# Database Unix socket paths into the '/jbt/run' directory
JBT_DB_SOCKETS=("${JBT_S_MY}" "${JBT_S_MY}" "${JBT_S_MA}" "${JBT_S_MA}" "${JBT_S_PG}")

# Valid PHP versions to choose from for available Joomla Docker images
JBT_VALID_PHP_VERSIONS=("php5.6" "php7.0" "php7.1" "php7.2" "php7.3" "php7.4" "php8.0" "php8.1" "php8.2" "php8.3" "highest")

# Highest PHP versions for Joomla versions (6 November 2024: There are no images 5.3 and higher)
JBT_JOOMLA_VERSIONS=("39" "310" "40" "41" "42" "43" "44" "50" "51" "52")
JBT_PHP_VERSIONS=("php7.4" "php8.0" "php8.0" "php8.0" "php8.1" "php8.2" "php8.2" "php8.2" "php8.3" "php8.3")

# Base Docker containers, eg ("jbt-pga" "jbt-mya" "jbt-mysql" "jbt-madb" "jbt-pg" "jbt-relay" "jbt-mail" "jbt-cypress" "jbt-novnc")
JBT_BASE_CONTAINERS=()
while read -r line; do
  JBT_BASE_CONTAINERS+=("$line")
done < <(grep 'container_name:' docker-compose.base.yml | awk '{print $2}')

# If the 'unpatched' option is not set and no patch is provided, use the following list:
# As of early October 2024, the main functionality is working without the need for patches.
# shellcheck disable=SC2034 # It is used by other scripts after sourcing
JBT_DEFAULT_PATCHES=("unpatched")

# Variables that are used by helper.sh only and retrived on first usage
# All used tags
JBT_HELPER_TAGS=()
# All used branches
JBT_HELPER_BRANCHES=()

# Determine Joomla valid (>= 3.9) version tags.
# Returns an array, e.g. ("1.7.3" "2.5.0" ... "5.2.0" "5.2.0-rc1" ...)
# They are at least 4 chars (e.g. '1.7.3'), not using 'deprecate_eval', '11.2' etc.
#
# Joomla Docker images <= 3.8 cannot run 'apt-get update'.
#
# Get on first call and stored in JBT_HELPER_TAGS.
#
function getAllUsedTags() {
  if [[ ${#JBT_HELPER_TAGS[@]} -eq 0 ]]; then
    # get tags | remove dereferenced annotated tag '^{}' lines | \
    #            remove commit hash and 'refs/tags/' in the lines | only 1-9.* | version sort | replace new line with space
    # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
    read -a JBT_HELPER_TAGS <<< "$(git ls-remote --tags https://github.com/joomla/joomla-cms | grep -v '\^{}' | \
                        sed 's/.*\///' | grep '^[1-9]\.' | sort -V | awk -F. '$1 > 3 || ($1 == 3 && $2 >= 9)' | tr '\n' ' ')"
  fi
  echo "${JBT_HELPER_TAGS[*]}"
}

# Determine the currently used Joomla branches.
# Returns a space-separated string of branches, e.g. getAllUsedBranches -> "4.4-dev 5.2-dev 5.3-dev 6.0-dev".
#
# We are using default, active and stale branches.
# With ugly screen-scraping, because no git command found and GitHub API with token looks too oversized.
# If we are offline, it returns an empty list.
#
function getAllUsedBranches() {

  if [[ ${#JBT_HELPER_BRANCHES[@]} -eq 0 ]]; then
    # Declare all local variables to prevent SC2155 - Declare and assign separately to avoid masking return values.
    local json_data stale_json_data branches

    # Get the JSON data from both the main branches and stale branches URLs
    json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches")
    stale_json_data=$(curl -s "https://github.com/joomla/joomla-cms/branches/stale")

    # Extract the names of the branches, only with grep and sed, so as not to install any dependencies, e.g. jq
    # Use sed with -E flag to enable extended regular expressions, which is also working with macOS sed.
    branches=$(echo "$json_data" "$stale_json_data" | grep -o '"name":"[0-9]\+\.[0-9]\+-dev"' |
               sed -E 's/"name":"([0-9]+)\.([0-9]+)-dev"/\1\2/')
    
    # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
    read -a JBT_HELPER_BRANCHES <<< "$(echo "${branches}" | tr ' ' '\n' | sort -n | tr '\n' ' ')"
  fi
  echo "${JBT_HELPER_BRANCHES[*]}"
}

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

# Check if the given argument is a Joomla used branch or Joomla used tag version.
# e.g. isValidVersion "44" -> 0
# e,g, isValidVersion "5.2-0-alpha3" -> 0
#
function isValidVersion() {

  if [ -z "$1" ]; then
    return 1 # Not a valid version
  fi
  local version="$1" fullVersion versions=()
  fullVersion=$(fullName "$1" | awk '{print $1}')

  # Branch? e.g. 5.3-dev
  # shellcheck disable=SC2207 # There are no spaces in version numbers
  branches=($(getAllUsedBranches))
  for branch in "${branches[@]}"; do
    if [[ "${branch}" == "${version}" || "${branch}" == "${fullVersion}" ]]; then
      return 0 # success
    fi
  done

  # Abbreviated branch name? e.g. "53"
  # shellcheck disable=SC2207 # There are no spaces in version numbers
  branches=($(fullName "${branches[*]}"))
  for branch in "${branches[@]}"; do
    if [[ "${branch}" == "${version}" || "${branch}" == "${fullVersion}" ]]; then
      return 0 # success
    fi
  done

  # Tag? e.g. "5.2.0"
  # shellcheck disable=SC2207 # There are no spaces in version numbers
  tags=($(getAllUsedTags))
  for tag in "${tags[@]}"; do
    if [[ "${tag}" == "${version}" || "${tag}" == "${fullVersion}" ]]; then
      return 0 # success
    fi
  done

  # Abbreviated tag name? e.g. "520"
  # shellcheck disable=SC2207 # There are no spaces in version numbers
  tags=($(fullName "${tags[*]}"))
  for tag in "${tags[@]}"; do
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
# e.g. isValidPHP "php7.2" -> 1
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

# Returns the full Git branch or tag name corresponding for the abbreviation.
# Works on single entry and space separated lists.
# e.g. fullName "520-alpha4" -> '5.2.0-alpha4'
# e.g. fullName "52 53" -> '5.2-dev 5.3-dev'
#
function fullName() {
  if [[ -z "$1" ]]; then
    error "fullName(): missing version"
  fi

  local branches=()
  for version in $1; do
    if [[ "$version" =~ ^[0-9]{2}$ ]]; then
      # Two digits branch? e.g. "44" -> "4.4-dev"
      branches+=("$(echo "$version" | sed -E 's/([0-9])([0-9])/\1.\2-dev/')")
    elif [[ "$version" =~ ^([0-9])([0-9])([0-9])(.*)$ ]]; then
      # Three digits tag? e.g. "520-aplha4" to "5.2.0-alpha4"
      branches+=("${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}${BASH_REMATCH[4]}")
    else
      # Keep the original
      branches+=("$version")
    fi
  done
  echo "${branches[*]}"
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

# Create 'docker-compose.yml' file with one or multiple web servers.
# 1st argument is e.g. "5.2-dev" or "4.4.1-alpha4 5.1.0"
# 2nd argument e.g. "php8.1" or "highest"
# 3rd argument is "IPv4" or "IPv6"
# 4th optional argument is "append", then the web server is inserted before volumes, if it is not already existing.
#
function createDockerComposeFile() {
  local php_version="$2"
  local network="$3"
  local working="$4"

  # Declare all local variables to prevent SC2155 - Declare and assign separately to avoid masking return values.
  local version versions=() din
  # shellcheck disable=SC2162 # Not set -r as 2nd option as it will not work for old Bashes and there are no backslashes here
  read -a versions <<< "$(echo "$1" | tr ' ' '\n' | sort -n | tr '\n' ' ')"

  if [ "${working}" = "append" ]; then
    # Cut named volumes, they are added always in the end.
    csplit "docker-compose.yml" "/^volumes:/" && \
      cat xx00 >"docker-compose.new" && \
      rm xx00 xx01
  else
    if [ "${network}" = "IPv4" ]; then
      cp docker-compose.base.yml docker-compose.new
    else
      sed -e 's/enable_ipv6: false/enable_ipv6: true/' \
        -e 's/subnet: "192.168.150.0\/24"/subnet: "fd00::\/8"/' \
        docker-compose.base.yml >docker-compose.new

    fi
  fi

  for version in "${versions[@]}"; do
    local doit=true
    instance=$(getMajorMinor "${version}")
    din=$(dockerImageName "${version}" "${php_version}")
    checkDockerImageName "${instance}" "${din:7}" # e.g. 'joomla:5.0-php8.2-apache' as '5.0-php8.2-apache'
    padded=$(getMajorMinor "${version}" "pad")
    if [ "${working}" = "append" ]; then
      if grep -q "^  jbt-${instance}" docker-compose.new; then
        log "jbt-${instance} – An entry already exists in 'docker-compose.yml'; leave it unmodified"
        doit=false
      fi
    fi
    if $doit; then
      # Add Joomla web server entry.
      #   e.g. 5.2.9   -> 52 for VVV, 0 for WWW,  52 for XXX, 052 for ZZZ and 5 for YYY
      #   e.g. 3.10.12 -> 10 for VVV, 3 for WWW, 310 for XXX, 310 for ZZZ and 3 for YYY
      log "jbt-${instance} – Adding an entry to 'docker-compose.yml' using the '${din}' image"
      sed -e '/^#/d' \
          -e "s/VVV/${padded: -2}/" \
          -e "s/WWW/${padded:0:1}/" \
          -e "s/XXX/${instance}/" \
          -e "s/YYY/${din}/" \
          -e "s/ZZZ/${padded}/" docker-compose.joomla.yml >>docker-compose.new
    fi
  done

  # Add named volumes definition.
  sed -e '/^#/d' docker-compose.end.yml >>docker-compose.new

  # Finally rename it
  mv docker-compose.new docker-compose.yml
}

# Check if Joomla Docker exist.
# e.g. checkDockerImageName "52" "5.2-php8.1-apache"
#
# If not, give error and list available PHP versions and exit.
#
function checkDockerImageName {
  local instance="$1" din="${2}" status php_version searching valid=()

  status=$(curl -s -o /dev/null -w "%{http_code}" "https://hub.docker.com/v2/repositories/library/joomla/tags/${din}")
  if [ "${status}" != "200" ]; then
    error "jbt-${instance} – There is no Docker image '${din}' available."
    searching="${instance:0:1}.${instance:1}"
    for php_version in "${JBT_VALID_PHP_VERSIONS[@]}"; do
      tag="${searching}-${php_version}-apache"
      status=$(curl -s -o /dev/null -w "%{http_code}" "https://hub.docker.com/v2/repositories/library/joomla/tags/${tag}")
      if [ "${status}" = "200" ]; then
        valid+=("${php_version}")
      fi
    done
    error "For Joomla ${instance}, please use one PHP versions of: ${valid[*]}, or use default 'highest'."
    exit 1
  fi
}

# Returns existing Docker image name for given Joomla and PHP version.
#   e.g. dockerImageName "4.4-dev" "php8.1" -> "4.4-php8.1-apache"
#   e.g. dockerImageName "3.9" "highest" -> "3.9-php7.4-apache"
#   exceptions/restrictions:
#   - Docker images starting with Joomla 3.4 (but as with not working npm we start with >= 3.9)
#   - There are no Joomla 5.3 and 6.0 images fallback to Joomla 5.2
#
# see https://hub.docker.com/_/joomla/tags and fast testable by e.g.:
#   curl -s -o /dev/null -w "%{http_code}" https://hub.docker.com/v2/repositories/library/joomla/tags/4.0-php8.0-apache
#
function dockerImageName() {
  local instance php_version="$2" php_to_use instance_to_use
  instance=$(getMajorMinor "$1")

  if [ "${php_version}" = "highest" ]; then
    for i in "${!JBT_JOOMLA_VERSIONS[@]}"; do
      if [ "${JBT_JOOMLA_VERSIONS[$i]}" = "${instance}" ]; then
        php_to_use="${JBT_PHP_VERSIONS[$i]}"
      fi
    done
    # Trust in God, no error handling here
  else
    php_to_use="${php_version}"
  fi

  if (( instance != 310 && instance > 52 )); then
    # Currently (6 November 2024) there are no Joomla 5.3 and higher Docker images, simple use 5.2 as base.
    instance_to_use="52"
    php_to_use="php8.3"
  else
    instance_to_use="${instance}"
  fi

  echo "joomla:${instance_to_use:0:1}.${instance_to_use:1}-${php_to_use}-apache"
}

# Retrieve the installed Joomla major and minor version from the `libraries/src/Version.php` file in the specified branch directory.
# e.g. getJoomlaVersion "joomla-51" -> "51"
#
function getJoomlaVersion() {
  local versions_file="$1/libraries/src/Version.php"

  if [ ! -f "$versions_file" ]; then
    error "There is no file \"${versions_file}\"."
    exit 1
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

# Use ANSI escape sequences to colorize JBT log messages to differentiate them from others.
#
JBT_UNDERLINE="\033[4m"
JBT_GREEN_BG="\033[42m"
JBT_RED="\033[0;31m"
JBT_BOLD="\033[1m"
JBT_RESET="\033[0m"

# Is the 'NO_COLOR' environment variable set and non-empty?
if [ -n "${NO_COLOR}" ]; then
  # Do not use color for log messages.
  JBT_UNDERLINE=""
  JBT_GREEN_BG=""
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
log ">>> '$0${*:+ $*}' started"

# Instance is JBT version < 2.0.0 created and we are not running 'scripts/clean'?
if [ -f "docker-compose.yml" ] && [ "$0" != "scripts/clean.sh" ] && grep -q "jbt_cypress" "docker-compose.yml"; then
    error "Installation < 2.0.0 found, hostnames changed. You need first to run 'scripts/create'."
    # Give only warning, don't stop as we may running 'scripts/create'
elif find . -maxdepth 1 -type d -name "branch_*" | grep -q . && [ "$0" != "scripts/clean.sh" ]; then
    # Instance is JBT version < 2.0.8. created and we are not running 'scripts/clean'
    error "Installation < 2.0.8 found, branch directory names changed. You need first to run 'scripts/create'."
    # Give only warning, don't stop as we may running 'scripts/create'
fi
