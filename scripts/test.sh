#!/bin/bash
#
# test.sh - Runs tests on one, multiple, or all branches, e.g.
#   scripts/test
#   scripts/test system novnc firefox
#   scripts/test 44 lint:testjs
#   scripts/test 52 53 system edge site/components/com_contact/Categories.cy.js
#   scripts/test system 'tests/System/integration/site/**/*.cy.{js,jsx,ts,tsx}'
#   ELECTRON_ENABLE_LOGGING=1 scripts/test system
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/test'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh
# test script counts errors by own and should not stop on command failures
trap - ERR

function help {
    echo "
    test – Runs tests on one, multiple, or all branches.
           Optional Joomla version can be one or more of the following: ${allVersions[*]} (default is all).
           Optional 'novnc' argument sets DISPLAY=jbt-novnc:0 (default is headless).
           Optional 'chrome', 'edge', or 'firefox' can be specified as the browser (default is 'electron').
           Optional test name can be on or more of the following: ${ALL_TESTS[*]} (default is all).
           Optional Cypress spec file pattern for 'system' tests (default is to run all w/o the installation step)

           $(random_quote)
    "
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getVersions))

ALL_TESTS=("php-cs-fixer" "phpcs" "unit" "lint:css" "lint:js" "lint:testjs" "system")
testsToRun=()
novnc=false
browser=""
versionsToTest=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${allVersions[*]}"; then
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
  # Check argument contains at least one slash to prevent typos, to be taken as the test pattern.
  elif [[ "$1" == */* ]]; then
    spec_argument="$1"
    shift # Argument is eaten as test spec pattern.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# If no version was given, use all.
if [ ${#versionsToTest[@]} -eq 0 ]; then
  versionsToTest=("${allVersions[@]}")
fi

# If no test name was given, use all.
if [ ${#testsToRun[@]} -eq 0 ]; then
  testsToRun=("${ALL_TESTS[@]}")
fi

# Pass through the environment variable to show 'console.log()' messages
eel1=""
if [ "$ELECTRON_ENABLE_LOGGING" == "1" ]; then
  eel1="ELECTRON_ENABLE_LOGGING=1"
fi

overallFailed=0
overallSuccessful=0

for version in "${versionsToTest[@]}"; do

  if [ ! -d "branch-${version}" ]; then
    log "jbt-${version} – There is no directory 'branch-${version}', jumped over"
    continue
  fi

  failed=0
  successful=0

  for actualTest in "${testsToRun[@]}"; do

    if [ "$actualTest" = "php-cs-fixer" ]; then
      log "jbt-${version} – Initiating PHP Coding Standards Fixer – php-cs-fixer"
      # 1st To prevent failure, we fix the auto-generated file before
      docker exec "jbt-${version}" bash -c \
        'file="administrator/cache/autoload_psr4.php"; [ -f "${file}" ] && libraries/vendor/bin/php-cs-fixer fix "${file}"' || true
      # 2nd Ignore Joomla Patch Tester
      insert_file="branch-${version}/.php-cs-fixer.dist.php"
      insert_line="    ->notPath('/com_patchtester/')"
      if [ -d "branch-${version}/administrator/components/com_patchtester" ] && \
         [ -f "${insert_file}" ] && ! grep -qF "${insert_line}" "${insert_file}"; then
        log "jbt-${version} – Patch Tester installation found, excluding from PHP-CS-Fixer"
        # file is owned by 'www-data' user on Linux
        chmod 666 "${insert_file}" 2>/dev/null || sudo chmod 666 "${insert_file}"
        csplit "${insert_file}" "/->notPath('/" && \
          cat xx00 > "${insert_file}" && \
          echo "${insert_line}" >> "${insert_file}" && \
          cat xx01 >> "${insert_file}" && \
          rm xx00 xx01
      fi
      if docker exec "jbt-${version}" bash -c "libraries/vendor/bin/php-cs-fixer fix -vvv --dry-run --diff"; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${version} – php-cs-fixer passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt-${version} – php-cs-fixer failed."
      fi
    fi

    if [ "$actualTest" = "phpcs" ]; then
      log "jbt-${version} – Initiating PHP Coding Sniffer – phpcs"
      # 1st Ignore Joomla Patch Tester
      insert_file="branch-${version}/ruleset.xml"
      insert_line='    <exclude-pattern type="relative">^administrator/components/com_patchtester/*</exclude-pattern>'
      if [ -d "branch-${version}/administrator/components/com_patchtester" ] && \
         [ -f "${insert_file}" ] && ! grep -qF "${insert_line}" "${insert_file}"; then
        csplit "${insert_file}" "/<exclude-pattern /" && \
          cat xx00 > "${insert_file}" && \
          echo "${insert_line}" >> "${insert_file}" && \
          cat xx01 >> "${insert_file}" && \
          rm xx00 xx01
      fi
      if docker exec "jbt-${version}" bash -c "libraries/vendor/bin/phpcs --extensions=php -p --standard=ruleset.xml ."; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${version} – phpcs passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt-${version} – phpcs failed."
      fi
    fi

    # TODO phan

    if [ "$actualTest" = "unit" ]; then
      log "jbt-${version} – Initiating PHP Testsuite Unit – unit"
      if docker exec "jbt-${version}" bash -c "libraries/vendor/bin/phpunit --testsuite Unit"; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${version} – unit passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt-${version} – unit failed."
      fi
    fi

    # TODO ?needs? LDAP
    # if [ "$actualTest" = "integration" ]; then
    #   log "jbt-${version} – Initiating PHP Unit Testsuite Integration – integration"
    #   docker exec "jbt-${version}" bash -c "libraries/vendor/bin/phpunit --testsuite Integration"
    #   if [ $? -eq 0 ]; then
    #     successful=$((successful + 1))
    #     overallSuccessful=$((overallSuccessful + 1))
    #     log "jbt-${version} – integration passed successfully"
    #   else
    #     failed=$((failed + 1))
    #     overallFailed=$((failed + 1))
    #     error "jbt-${version} – integration failed."
    #   fi
    # fi

    # TODO integration-pg

    for lint in "css" "js" "testjs" ; do
      if [ "$actualTest" = "lint:${lint}" ]; then
        log "jbt-${version} – Initiating ${lint} Linter – lint:${lint}"
        if docker exec "jbt-${version}" bash -c "npm run lint:${lint}"; then
          successful=$((successful + 1))
          overallSuccessful=$((overallSuccessful + 1))
          log "jbt-${version} – lint:${lint} passed successfully"
        else
          failed=$((failed + 1))
          overallFailed=$((failed + 1))
          error "jbt-${version} – lint:${lint} failed."
        fi
    fi
    done

    if [ "$actualTest" = "system" ]; then
      # Is there one more argument with a test spec pattern?
      if [ -z "$spec_argument" ] ; then
        # Create spec pattern list without installation spec
        i="tests/System/integration/"
        all=$(grep  "${i}" "branch-${version}/cypress.config.mjs" | \
              grep -v "${i}install/" | \
              tr -d "' " | \
              awk '{printf "%s", $0}' | \
              sed 's/,$//')
        spec="--spec '${all}'"
      else
        # Use the given test spec pattern and check if we can (no pattern) and must (missing path) insert path
        if [[ "$spec_argument" != *","* && "$spec_argument" != tests/System/integration/* ]]; then
          spec="--spec 'tests/System/integration/$spec_argument'"
        else
          spec="--spec '$spec_argument'"
        fi
      fi

      # 16 September 2024 disabled, because Error: Unwanted PHP Deprecated
      # # Temporarily disable Joomla logging as System Tests are failing.
      # log "jbt-${version} – Temporarily disable Joomla logging"
      # docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
      #   -e 's/\$debug = .*/\$debug = false;/' \
      #   -e 's/\$log_everything = .*/\$log_everything = 0;/' \
      #   -e 's/\$log_deprecated = .*/\$log_deprecated = 0;/' \
      #   configuration.php > configuration.php.tmp && \
      #   mv configuration.php.tmp configuration.php"
        
      if [[ "$novnc" == true ]]; then
        log "jbt-${version} – Initiating System Tests with NoVNC and ${spec}"
        docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && export DISPLAY=jbt-novnc:0 && ${eel1} cypress run --headed ${browser} ${spec}"
      else
        log "jbt-${version} – Initiating headless System Tests with ${spec}"
        docker exec jbt-cypress sh -c "cd /jbt/branch-${version} && unset DISPLAY && ${eel1} cypress run ${browser} ${spec}"
      fi
      # shellcheck disable=SC2181 # Check either Cypress headed or headless status 
      if [ $? -eq 0 ] ; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${version} – System Tests passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((failed + 1))
        error "jbt-${version} – System Tests failed."
      fi

      # 16 September 2024 disabled, because Error: Unwanted PHP Deprecated
      # Enable Joomla logging
      # log "jbt-${version} – Re-enabling Joomla logging"
      # docker exec "jbt-${version}" bash -c "cd /var/www/html && sed \
      #   -e 's/\$debug = .*/\$debug = true;/' \
      #   -e 's/\$log_everything = .*/\$log_everything = 1;/' \
      #   -e 's/\$log_deprecated = .*/\$log_deprecated = 1;/' \
      #   configuration.php > configuration.php.tmp && \
      #   mv configuration.php.tmp configuration.php"
    fi
  done

  if [ ${failed} -eq 0 ] ; then
    log "jbt-${version} – Test run completed: ${successful} test(s) passed ${spec}"
  else
    error "jbt-${version} – Test run completed: ${failed} test(s) failed, ${successful} test(s) passed ${spec}."
  fi

done

if [ ${#versionsToTest[@]} -gt 1 ]; then
  if [ ${overallFailed} -eq 0 ] ; then
    log "${versionsToTest[*]} – All tests completed: ${overallSuccessful} test(s) successful ${spec}"
    exit 0
  else
    error "${versionsToTest[*]} – All tests completed: ${overallFailed} test(s) failed, ${overallSuccessful} test(s) passed ${spec}."
    exit 1
  fi
fi
