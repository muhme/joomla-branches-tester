# helper.sh - bash script helper functions
#
# Implementation without associative arrays to also work with macOS standard 3.2 bash.
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

# As branches available Joomla versions, have to match the defined containers
VERSIONS=(44 51 52 60)

# Database and database driver variants as in configuration.php 'dbtype'
DB_VARIANTS=("mysqli"    "mysql"       "mariadbi" "mariadb"     "pgsql"           )
# Database driver mapping for the variants as in Web Installer 'database type'
DB_TYPES=   ("MySQLi"    "MySQL (PDO)" "MySQLi"   "MySQL (PDO)" "PostgreSQL (PDO)")
# Database server mapping for the variants
DB_HOSTS=   ("jbt_mysql" "jbt_mysql"   "jbt_madb" "jbt_madb"    "jbt_pg"          )

# Get database type for variant
#
dbTypeForVariant() {
    local variant=$1
    for i in "${!DB_VARIANTS[@]}"; do
        if [ "${DB_VARIANTS[$i]}" = "$variant" ]; then
            echo "${DB_TYPES[$i]}"
            return
        fi
    done
    error "No database type found for variant'$1'"
}

# Get database host for variant
#
dbHostForVariant() {
    local variant=$1
    for i in "${!DB_VARIANTS[@]}"; do
        if [ "${DB_VARIANTS[$i]}" = "$variant" ]; then
            echo "${DB_HOSTS[$i]}"
            return
        fi
    done
    error "No database host found for variant'$1'"
}

# Check if the given argument is a valid Joomla version
#
isValidVersion() {
    local version="$1"
    for v in "${VERSIONS[@]}"; do
        if [[ "$v" == "$version" ]]; then
            return 0 # success
        fi
    done
    return 1 # nope
}

# Check if the given argument is a valid database variant
#
isValidVariant() {
    local variant="$1"
    for v in "${DB_VARIANTS[@]}"; do
        if [[ "$v" == "$variant" ]]; then
            return 0 # success
        fi
    done
    return 1 # nope
}

if [ -n "$NO_COLOR" ]; then
    # NO_COLOR is set, it is non empty
    LIGHT_GREEN_BG=""
    GREEN_BG=""
    RED=""
    BOLD=""
    RESET=""
else
    # using ANSI escape sequences to find the log messages
    LIGHT_GREEN_BG="\033[102m"
    GREEN_BG="\033[42m"
    RED="\033[0;31m"
    BOLD="\033[1m"
    RESET="\033[0m"
fi

# Give log message with date and time in bold and dark red on stdout
#
log() {

    # NO_COLOR 

    # -e enables backslash escapes
    echo -e "${GREEN_BG}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}

# Give log message with date and time in bold and dark red on stdout
#
error() {
    # -e enables backslash escapes
    echo -e "${GREEN_BG}${RED}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}

# Returns git branch name for version number
# e.g. returns '5.1-dev' for '51'
#
branchName() {
    if [[ -z "$1" ]]; then
        echo "missing version"
        return 1
    else
        echo "${1}" | sed -E 's/([0-9])([0-9])/\1.\2-dev/'
    fi
}
