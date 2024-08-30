#!/bin/bash
#
# test.sh - test cypress spec on one, multiple or all branches, e.g.
#   scripts/test.sh
#   scripts/test.sh firefox
#   scripts/test.sh 44
#   scripts/test.sh 52 53 edge site/components/com_contact/Categories.cy.js
#   scripts/test.sh 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
#   ELECTRON_ENABLE_LOGGING=1 scripts/test.sh
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh
# test script counts errors by own and should not stop on command failures
trap - ERR

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

browser=""
versionsToTest=()
while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToTest+=("$1")
    shift # Argument is eaten as the Joomla version number.
  elif [[ "$1" =~ ^(chrome|edge|firefox|electron)$ ]]; then
    browser="--browser $1"
    shift # Argument is eaten as browser to use.
  else
    spec_argument="$1"
    shift # Argument is eaten as test specification.
  fi
done

# If no version was given, use all.
if [ ${#versionsToTest[@]} -eq 0 ]; then
  versionsToTest=(${allVersions[@]})
fi

# Pass through the environment variable to show 'console.log()' messages
eel1=""
if [ "$ELECTRON_ENABLE_LOGGING" == "1" ]; then
  eel1="ELECTRON_ENABLE_LOGGING=1"
fi

failed=0
successful=0
for version in "${versionsToTest[@]}"
do

  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi

  # Is there one more argument with a test spec pattern?
  if [ -z "$spec_argument" ] ; then
    # Running everything, but without installation step
    # Handle .js or .mjs from PR https://github.com/joomla/joomla-cms/pull/43676 – [4.4] Move the Cypress Tests to ESM
    cf="branch_${version}/cypress.config"
    if [ -f "${cf}.js" ]; then
      cf="${cf}.js"
    elif [ -f "${cf}.mjs" ]; then
      cf="${cf}.mjs"
    else
      error "No 'cypress.config.*js' file found in branch_${version}. Please use 'scripts/create.sh' first."
      exit 1
    fi
    # Create spec pattern list without installation spec
    i="tests/System/integration/"
    all=$(grep  "${i}" "${cf}" | grep -v "${i}install/" | tr -d "' " | awk '{printf "%s", $0}' | sed 's/,$//')
    spec="--spec '${all}'"
  else
    # Use the given test spec pattern and check if we can (no pattern) and must (missing path) insert path
    if [[ "$spec_argument" != *","* && "$spec_argument" != tests/System/integration/* ]]; then
      spec="--spec 'tests/System/integration/$spec_argument'"
    else
      spec="--spec '$spec_argument'"
    fi
  fi

  log "Testing version ${version} with ${spec}."
  docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && ${eel1} cypress run ${browser} ${spec}"
  if [ $? -eq 0 ] ; then
    # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ ${failed} -eq 0 ] ; then
  log "Completed version ${versionsToTest[@]} with ${successful} successful ${spec}."
else
  error "Completed version ${versionsToTest[@]} with ${failed} failed and ${successful} successful ${spec}."
fi
