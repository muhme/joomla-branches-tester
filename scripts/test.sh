#!/bin/bash
#
# test.sh - Runs Cypress specs on one, multiple, or all branches, e.g.
#   scripts/test.sh
#   scripts/test.sh system novnc firefox
#   scripts/test.sh 44 lint:testjs
#   scripts/test.sh 52 53 system edge site/components/com_contact/Categories.cy.js
#   scripts/test.sh system 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
#   ELECTRON_ENABLE_LOGGING=1 scripts/test.sh system
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh
# test script counts errors by own and should not stop on command failures
trap - ERR

function help {
    echo "
    test.sh – Runs Cypress specs on one, multiple, or all branches.
              Optional Joomla version can be one or more of the following: ${allVersions[@]} (default is all).
              Optional 'novnc' argument sets DISPLAY=jbt_novnc:0 (default is headless).
              Optional 'chrome', 'edge', or 'firefox' can be specified as the browser (default is 'electron').
              Optional test name can be on or more of the following: ${ALL_TESTS[@]} (default is all).

              $(random_quote)
    "
}

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

ALL_TESTS=("php-cs-fixer" "phpcs" "unit" "lint:css" "lint:js" "lint:testjs" "system")
testsToRun=()
novnc=false
browser=""
versionsToTest=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    versionsToTest+=("$1")
    shift # Argument is eaten as the Joomla version number.
  elif [ "$1" = "novnc" ]; then
    novnc=true
    shift # Argument is eaten as using NoVNC.
  elif [[ "$1" =~ ^(chrome|edge|firefox|electron)$ ]]; then
    browser="--browser $1"
    shift # Argument is eaten as browser to use.
  elif isValidTestName "$1" "${ALL_TESTS[@]}"; then
    testsToRun+=("$1")
    shift # Argument is eaten as test name.
  else
    spec_argument="$1"
    shift # Argument is eaten as test specification.
  fi
done

# If no version was given, use all.
if [ ${#versionsToTest[@]} -eq 0 ]; then
  versionsToTest=(${allVersions[@]})
fi

# If no test name was given, use all.
if [ ${#testsToRun[@]} -eq 0 ]; then
  testsToRun=(${ALL_TESTS[@]})
fi

# Pass through the environment variable to show 'console.log()' messages
eel1=""
if [ "$ELECTRON_ENABLE_LOGGING" == "1" ]; then
  eel1="ELECTRON_ENABLE_LOGGING=1"
fi

overallFailed=0
overallSuccessful=0

for version in "${versionsToTest[@]}"; do

  if [ ! -d "branch_${version}" ]; then
    log "jbt_${version} – There is no directory 'branch_${version}', jumped over."
    continue
  fi

  failed=0
  successful=0

  for actualTest in "${testsToRun[@]}"; do

    if [ "$actualTest" = "php-cs-fixer" ]; then
      log "jbt_${version} – Initiating PHP Coding Standards Fixer – php-cs-fixer"
      docker exec "jbt_${version}" bash -c "libraries/vendor/bin/php-cs-fixer fix -vvv --dry-run --diff"
      if [ $? -eq 0 ]; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt_${version} – php-cs-fixer passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt_${version} – php-cs-fixer failed"
      fi
    fi

    if [ "$actualTest" = "phpcs" ]; then
      log "jbt_${version} – Initiating PHP Coding Sniffer – phpcs"
      docker exec "jbt_${version}" bash -c "libraries/vendor/bin/phpcs --extensions=php -p --standard=ruleset.xml ."
      if [ $? -eq 0 ]; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt_${version} – phpcs passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt_${version} – phpcs failed"
      fi
    fi

    # TODO phan

    if [ "$actualTest" = "unit" ]; then
      log "jbt_${version} – Initiating PHP Testsuite Unit – unit"
      docker exec "jbt_${version}" bash -c "libraries/vendor/bin/phpunit --testsuite Unit"
      if [ $? -eq 0 ]; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt_${version} – unit passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt_${version} – unit failed"
      fi
    fi

    # TODO ?needs? LDAP
    # if [ "$actualTest" = "integration" ]; then
    #   log "jbt_${version} – Initiating PHP Unit Testsuite Integration – integration"
    #   docker exec "jbt_${version}" bash -c "libraries/vendor/bin/phpunit --testsuite Integration"
    #   if [ $? -eq 0 ]; then
    #     successful=$((successful + 1))
    #     overallSuccessful=$((overallSuccessful + 1))
    #     log "jbt_${version} – integration passed successfully"
    #   else
    #     failed=$((failed + 1))
    #     overallFailed=$((failed + 1))
    #     error "jbt_${version} – integration failed"
    #   fi
    # fi

    # TODO integration-pg

    for lint in "css" "js" "testjs" ; do
      if [ "$actualTest" = "lint:${lint}" ]; then
        log "jbt_${version} – Initiating ${lint} Linter – lint:${lint}"
        docker exec "jbt_${version}" bash -c "npm run lint:${lint}"
        if [ $? -eq 0 ]; then
          successful=$((successful + 1))
          overallSuccessful=$((overallSuccessful + 1))
          log "jbt_${version} – lint:${lint} passed successfully"
        else
          failed=$((failed + 1))
          overallFailed=$((failed + 1))
          error "jbt_${version} – lint:${lint} failed"
        fi
    fi
    done

    if [ "$actualTest" = "system" ]; then
      # Is there one more argument with a test spec pattern?
      if [ -z "$spec_argument" ] ; then
        # Initiating everything, but without installation step
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

      if [[ "$novnc" == true ]]; then
        log "jbt_${version} – Initiating System Tests with NoVNC and ${spec}."
        docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && export DISPLAY=jbt_novnc:0 && ${eel1} cypress run --headed ${browser} ${spec}"
      else
        log "jbt_${version} – Initiating headless System Tests with ${spec}."
        docker exec -it jbt_cypress sh -c "cd /jbt/branch_${version} && unset DISPLAY && ${eel1} cypress run ${browser} ${spec}"
      fi
      if [ $? -eq 0 ] ; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt_${version} – System Tests passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt_${version} – System Tests failed"
      fi
    fi
  done

  if [ ${failed} -eq 0 ] ; then
    log "jbt_${version} – Test run completed: ${successful} test(s) passed ${spec}"
  else
    error "jbt_${version} – Test run completed: ${failed} test(s) failed, ${successful} test(s) passed ${spec}"
  fi

done

if [ ${#versionsToTest[@]} -gt 1 ]; then
  if [ ${overallFailed} -eq 0 ] ; then
    log "${versionsToTest[@]} – All tests completed: ${overallSuccessful} test(s) successful ${spec}"
    exit 0
  else
    error "${versionsToTest[@]} – All tests completed: ${overallFailed} test(s) failed, ${overallSuccessful} test(s) passed ${spec}"
    exit 1
  fi
fi
