# helper.sh - bash script helper functions
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

# as branches available Joomla versions, have to match the defined containers
VERSIONS=(44 51 52 60)

# using ANSI escape sequences to find the log messages
LIGHT_GREEN_BG="\033[102m"
GREEN_BG="\033[42m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

# give log message with date and time in bold and dark red on stdout
#
log() {
    # -e enables backslash escapes
    echo -e "${GREEN_BG}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}

# give log message with date and time in bold and dark red on stdout
#
error() {
    # -e enables backslash escapes
    echo -e "${GREEN_BG}${RED}${BOLD}*** $(date '+%y%m%d %H:%M:%S') *** $@${RESET}"
}
