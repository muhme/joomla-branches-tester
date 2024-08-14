# helper.sh - bash script helper functions
#
# Implementation without associative arrays to also work with macOS standard 3.2 bash.
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

# Database and database driver variants as in configuration.php 'dbtype'
JBT_DB_VARIANTS=("mysqli" "mysql" "mariadbi" "mariadb" "pgsql")
# Database driver mapping for the variants as in Web Installer 'database type'
JBT_DB_TYPES=("MySQLi" "MySQL (PDO)" "MySQLi" "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants
JBT_DB_HOSTS=("jbt_mysql" "jbt_mysql" "jbt_madb" "jbt_madb" "jbt_pg")

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
    local branches=$(echo "$json_data" | grep -o '"name":"[0-9]\+\.[0-9]\+-dev"' | sed 's/"name":"\([0-9]\+\)\.\([0-9]\+\)-dev"/\1\2/')

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

# Check if the given argument is a valid Joomla version
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
    error "No database type found for variant'$1'"
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
    error "No database host found for variant'$1'"
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

# Create docker-compose.ymk with one or all four Joomla web servers
# argument is e.g. "52" or "44 51 52 60"
#
function createDockerComposeFile() {
    log "Create 'docker-compose.yml' file for $1"

    local versions=()
    IFS=' ' versions=($(sort <<<"$1"))
    unset IFS # map to array

    cp docker-compose.base.yml docker-compose.yml
    for version in "${versions[@]}"; do
        # joomla:4 or joomla:5 image?
        if [ "$$version" = "44" ]; then
            base="4"
        else
            base="5"
        fi
        sed -e "s/XX/${version}/" -e "s/Y/$base/" docker-compose.joomla.yml >>docker-compose.yml
    done
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

# Give log message with date and time in bold and dark red on stdout
#
log() {
    # -e enables backslash escapes
    echo -e "${JBT_GREEN_BG}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}"
}

# Give log message with date and time in bold and dark red on stdout
#
error() {
    # -e enables backslash escapes
    echo -e "${JBT_GREEN_BG}${JBT_RED}${JBT_BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${JBT_RESET}"
}
