# helper.sh - bash script helper functions
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

# as branches available Joomla versions, have to match the defined containers
VERSIONS=(44 51 52 60)

# check if the given argument is a valid version
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

# give log message with date and time in bold and dark red on stdout
#
log() {

    # NO_COLOR 

    # -e enables backslash escapes
    echo -e "${GREEN_BG}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}

# give log message with date and time in bold and dark red on stdout
#
error() {
    # -e enables backslash escapes
    echo -e "${GREEN_BG}${RED}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}

# returns git branch name for version number
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
