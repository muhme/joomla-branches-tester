# helper.sh - bash script helper functions
#
# Implementation without associative arrays to also work with macOS standard 3.2 bash.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

# Record the start time in seconds since 1.1.1970
start_time=$(date +%s)

# Database and database driver variants as in configuration.php 'dbtype'
JBT_DB_VARIANTS=("mysqli" "mysql" "mariadbi" "mariadb" "pgsql")
# Database driver mapping for the variants as in Web Installer 'database type'
JBT_DB_TYPES=("MySQLi" "MySQL (PDO)" "MySQLi" "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants
JBT_DB_HOSTS=("jbt_mysql" "jbt_mysql" "jbt_madb" "jbt_madb" "jbt_pg"          )
# Database port mapping for the variants
JBT_DB_PORTS=("7011"      "7011"      "7012"     "7012"     "7013"            )
# PHP versions to chooce from
JBT_PHP_VERSIONS=("php8.1" "php8.2" "php8.3")

# Determine actual active Joomla branches, e.g. "44 51 52 60"
#
# With ugly screen-scraping, because no git command found and GitHub API with token looks too oversized.
#
function getVersions() {
    # GitHub branch page of the repository joomla-cms
    local URL="https://github.com/joomla/joomla-cms/branches"

    # Get the JSON data mit curl
    local json_data=$(curl -s "$URL")

    # Extract the names of the branches, only with grep and sed, so as not to install any dependencies, e.g. jq
    # Use sed with -E flag to enable extended regular expressions, which is also working with macOS sed
    local branches=$(echo "$json_data" | grep -o '"name":"[0-9]\+\.[0-9]\+-dev"' | sed -E 's/"name":"([0-9]+)\.([0-9]+)-dev"/\1\2/')

    # Create as array
    local formatted_branches=()
    for branch in ${branches}; do
        formatted_branches+=("${branch}")
    done

    # Sort
    local sorted_branches=()
    IFS=$'\n' sorted_branches=($(sort <<<"${formatted_branches[*]}"))
    unset IFS

    echo "${sorted_branches[*]}"
}

# Check if the given argument is one valid Joomla version
# e.g. isValidVersion "44" "44 51 52 60"
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

# Check if the given argument is a valid PHP version
# e.g. isValidVersion "php8.1"
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

# Returns git branch name for version number
# e.g. returns '5.1-dev' for '51'
#
function branchName() {
    if [[ -z "$1" ]]; then
        echo "missing version"
        return 1
    else
        echo "${1}" | sed -E 's/([0-9])([0-9])/\1.\2-dev/'
    fi
}

# Get database type for variant
#
function dbTypeForVariant() {
    local variant=$1
    for i in "${!JBT_DB_VARIANTS[@]}"; do
        if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
            echo "${JBT_DB_TYPES[$i]}"
            return
        fi
    done
    error "No database type found for variant '$1'"
}

# Get database host for variant
#
function dbHostForVariant() {
    local variant=$1
    for i in "${!JBT_DB_VARIANTS[@]}"; do
        if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
            echo "${JBT_DB_HOSTS[$i]}"
            return
        fi
    done
    error "No database host found for variant '$1'"
}

# Get database host for variant
#
function dbPortForVariant() {
    local variant=$1
    for i in "${!JBT_DB_VARIANTS[@]}"; do
        if [ "${JBT_DB_VARIANTS[$i]}" = "$variant" ]; then
            echo "${JBT_DB_PORTS[$i]}"
            return
        fi
    done
    error "No database port found for variant '$1'"
}

# Check if the given argument is a valid database variant
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

# Create docker-compose.yml with one or all five Joomla web servers
# 1st argument is e.g. "52" or "44 51 52 53 60"
# 2nd argument e.g. "php8.1"
#
function createDockerComposeFile() {
    log "Create 'docker-compose.yml' file for version(s) $1 and $2."

    local php_version="$2"
    local versions=()
    IFS=' ' versions=($(sort <<<"$1")); unset IFS # map to array

    cp docker-compose.base.yml docker-compose.yml
    local version
    for version in "${versions[@]}"; do
        local din=$(dockerImageName "$version" "$php_version")
        sed -e "s/XX/${version}/" -e "s/Y/${din}/" docker-compose.joomla.yml >> docker-compose.yml
    done
}

# Returns existing Docker image name for given Joomla and PHP version.
#   e.g. dockerImage "44" "php8.1" -> "4.4-php8.1-apache"
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

# Get Joomla major and minor version from file system
# e.g. "51" for getJoomlaVersion "branch_51"  from file branch_51/libraries/src/Version.php
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

# using ANSI escape sequences to find the log messages
JBT_LIGHT_GREEN_BG="\033[102m"
JBT_GREEN_BG="\033[42m"
JBT_RED="\033[0;31m"
JBT_BOLD="\033[1m"
JBT_RESET="\033[0m"

if [ -n "$NO_COLOR" ]; then
    # NO_COLOR is set and it is non empty
    JBT_LIGHT_GREEN_BG=""
    JBT_GREEN_BG=""
    JBT_RED=""
    JBT_BOLD=""
    JBT_RESET=""
fi

# Return running time e.g. as "17 seconds" or as "3:18"
runningTime() {
    # Record the actual time in seconds since 1.1.1970
    actual_time=$(date +%s)

    # Calculate the elapsed time in minutes and seconds
    elapsed_time=$((actual_time - start_time))
    minutes=$((elapsed_time / 60))
    seconds=$((elapsed_time % 60))

    # Having seconds also formatted with a leading zero
    formatted_seconds=$(printf "%02d" $seconds)

    # Human readable outbut
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

# Give log message with date and time in bold and green background on stdout
#
log() {
    # -e enables backslash escapes
    echo -e "${JBT_GREEN_BG}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}"
}

# Give error message with date and time in bold and dark red on stderr
#
error() {
    # -e enables backslash escapes
    echo -e "${JBT_RED}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}" >&2
}

# As we have -e set the scripts exit immediately if any command fails.
# Show a red messge with script name and line number.
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
    log "Script '$(basename "$0")' finished in $(runningTime)."
}
trap theEnd EXIT

# No, every end is a new beginning :)
#
log "Script '$(basename "$0")' started."