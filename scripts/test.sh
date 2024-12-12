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
    test – Runs tests on one, multiple or all installed Joomla instances.
           The optional Joomla version can be one or more of: ${allInstalledInstances[*]} (default is all).
           The optional 'novnc' argument sets DISPLAY to jbt-novnc:0 (default is headless).
           Optional browser can be 'chrome', 'edge' or 'firefox' (default is 'electron').
           Specify an optional kind of test from: ${ALL_TESTS[*]}
           (defaults to ${ALL_JOOMLA_TESTS[*]}).
           Optional test spec file pattern for Cypress tests (defaults to all, but for 'system' without the installation step).
           The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

# shellcheck disable=SC2207 # There are no spaces in version numbers
allInstalledInstances=($(getAllInstalledInstances))

ALL_JOOMLA_TESTS=("php-cs-fixer" "phpcs" "unit" "lint:css" "lint:js" "lint:testjs" "system")
ALL_TESTS=("${ALL_JOOMLA_TESTS[@]}" "joomla-cypress")
testsToRun=()
novnc=false
browser=""
instancesToTest=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif [ -d "joomla-$1" ]; then
    instancesToTest+=("$1")
    shift # Argument is eaten as one version number.
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
if [ ${#instancesToTest[@]} -eq 0 ]; then
  instancesToTest=("${allInstalledInstances[@]}")
fi

if [ ${#testsToRun[@]} -gt 1 ]; then
  for test in "${testsToRun[@]}"; do
    if [ "${test}" = "joomla-cypress" ]; then
      error "The 'joomla-cypress' test cannot be combined with other tests."
      exit 1
    fi
  done
fi

# If no test name was given, use all.
if [ ${#testsToRun[@]} -eq 0 ]; then
  testsToRun=("${ALL_JOOMLA_TESTS[@]}")
fi

# Pass through the environment variable to show 'console.log()' messages
eel1=""
if [ "$ELECTRON_ENABLE_LOGGING" == "1" ]; then
  eel1="ELECTRON_ENABLE_LOGGING=1"
fi

overallFailed=0
overallSkipped=0
overallSuccessful=0

for instance in "${instancesToTest[@]}"; do

  failed=0
  skipped=0
  successful=0

  for actualTest in "${testsToRun[@]}"; do

    if [ "$actualTest" = "php-cs-fixer" ]; then
      if ((instance == 310 || instance < 44)); then
        # In Finder.php line 592: The "/var/www/html/installation" directory does not exist.
        log "jbt-${instance} < 44 Skipping PHP Coding Standards Fixer – php-cs-fixer"
        skipped=$((skipped + 1))
        overallSkipped=$((overallSkipped + 1))
        continue
      fi
      log "jbt-${instance} – Initiating PHP Coding Standards Fixer – php-cs-fixer"
      # 1st To prevent failure, we fix the auto-generated file before
      docker exec "jbt-${instance}" bash -c \
        'file="administrator/cache/autoload_psr4.php"; [ -f "${file}" ] && libraries/vendor/bin/php-cs-fixer fix "${file}"' || true
      # 2nd Ignore Joomla Patch Tester
      insert_file="joomla-${instance}/.php-cs-fixer.dist.php"
      insert_line="    ->notPath('/com_patchtester/')"
      if [ -d "joomla-${instance}/administrator/components/com_patchtester" ] &&
        [ -f "${insert_file}" ] && ! grep -qF "${insert_line}" "${insert_file}"; then
        log "jbt-${instance} – Patch Tester installation found, excluding from PHP-CS-Fixer"
        # file is owned by 'www-data' user on Linux
        chmod 666 "${insert_file}" 2>/dev/null || sudo chmod 666 "${insert_file}"
        csplit "${insert_file}" "/->notPath('/" &&
          cat xx00 >"${insert_file}" &&
          echo "${insert_line}" >>"${insert_file}" &&
          cat xx01 >>"${insert_file}" &&
          rm xx00 xx01
      fi
      if docker exec "jbt-${instance}" bash -c "libraries/vendor/bin/php-cs-fixer fix -vvv --dry-run --diff"; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${instance} – php-cs-fixer passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((overallFailed + 1))
        error "jbt-${instance} – php-cs-fixer failed."
      fi
    fi

    if [ "$actualTest" = "phpcs" ]; then
      if ((instance == 310 || instance < 42)); then
        # ERROR: the "ruleset.xml" coding standard is not installed.
        log "jbt-${instance} < 42 Skipping PHP Coding Sniffer – phpcs"
        skipped=$((skipped + 1))
        overallSkipped=$((overallSkipped + 1))
        continue
      fi
      log "jbt-${instance} – Initiating PHP Coding Sniffer – phpcs"
      # 1st Ignore Joomla Patch Tester
      insert_file="joomla-${instance}/ruleset.xml"
      insert_line='    <exclude-pattern type="relative">^administrator/components/com_patchtester/*</exclude-pattern>'
      if [ -d "joomla-${instance}/administrator/components/com_patchtester" ] &&
         [ -f "${insert_file}" ] && ! grep -qF "${insert_line}" "${insert_file}"; then
        csplit "${insert_file}" "/<exclude-pattern /" &&
          cat xx00 >"${insert_file}" &&
          echo "${insert_line}" >>"${insert_file}" &&
          cat xx01 >>"${insert_file}" &&
          rm xx00 xx01
      fi
      if docker exec "jbt-${instance}" bash -c "libraries/vendor/bin/phpcs --extensions=php -p --standard=ruleset.xml ."; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${instance} – phpcs passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((overallFailed + 1))
        error "jbt-${instance} – phpcs failed."
      fi
    fi

    # TODO phan

    if [ "$actualTest" = "unit" ]; then
      if ((instance == 310 || instance < 42)); then
        # No tests executed! /  PHP Fatal error:  Uncaught Error: Call to undefined function
        log "jbt-${instance} < 42 Skipping PHP Testsuite Unit – unit"
        skipped=$((skipped + 1))
        overallSkipped=$((overallSkipped + 1))
        continue
      fi
      log "jbt-${instance} – Initiating PHP Testsuite Unit – unit"
      if docker exec "jbt-${instance}" bash -c "libraries/vendor/bin/phpunit --testsuite Unit"; then
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${instance} – unit passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((overallFailed + 1))
        error "jbt-${instance} – unit failed."
      fi
    fi

    # TODO ?needs? LDAP
    # if [ "$actualTest" = "integration" ]; then
    #   log "jbt-${instance} – Initiating PHP Unit Testsuite Integration – integration"
    #   docker exec "jbt-${instance}" bash -c "libraries/vendor/bin/phpunit --testsuite Integration"
    #   if [ $? -eq 0 ]; then
    #     successful=$((successful + 1))
    #     overallSuccessful=$((overallSuccessful + 1))
    #     log "jbt-${instance} – integration passed successfully"
    #   else
    #     failed=$((failed + 1))
    #     overallFailed=$((overallFailed + 1))
    #     error "jbt-${instance} – integration failed."
    #   fi
    # fi

    # TODO integration-pg

    for lint in "css" "js" "testjs"; do
      if [ "$actualTest" = "lint:${lint}" ]; then
        if [[ "${instance}" -eq 310 || "${instance}" -lt 40 ||
              ("${actualTest}" == "lint:testjs" && "${instance}" -lt 44) ]]; then
          # No such file '/var/www/html/package.json' / Missing script: "lint:testjs"
          log "jbt-${instance} < 40 Skipping ${lint} Linter – lint:${lint}"
          skipped=$((skipped + 1))
          overallSkipped=$((overallSkipped + 1))
          continue
        fi
        log "jbt-${instance} – Initiating ${lint} Linter – lint:${lint}"
        if docker exec "jbt-${instance}" bash -c "npm run lint:${lint}"; then
          successful=$((successful + 1))
          overallSuccessful=$((overallSuccessful + 1))
          log "jbt-${instance} – lint:${lint} passed successfully"
        else
          failed=$((failed + 1))
          overallFailed=$((overallFailed + 1))
          error "jbt-${instance} – lint:${lint} failed."
        fi
      fi
    done

    # Cypress tests?
    if [[ "${actualTest}" =~ ^(system|joomla-cypress)$ ]]; then
      spec="${spec_argument}"

      # joomla-cypress' installJoomlaMultilingualSite() test deletes installation directory – restore it
      if [ ! -d "joomla-${instance}/installation" ]; then
        if [ -d "installation/joomla-${instance}/installation" ]; then
          log "jbt-${instance} – Restoring 'joomla-${instance}/installation' directory"
          cp -r "installation/joomla-${instance}/installation" "joomla-${instance}/installation" 2>/dev/null ||
            sudo cp -r "installation/joomla-${instance}/installation" "joomla-${instance}/installation"
          if [ -f "joomla-${instance}/package.json" ]; then
            log "jbt-${instance} – Running npm clean install"
            docker exec "jbt-${instance}" bash -c 'cd /var/www/html && npm ci'
          fi
        else
          error "jbt-${instance} – Missing 'joomla-${instance}/installation' directory"
          # Continue in the hope that it is not needed
        fi
      fi

      # Handle .js or .mjs from PR https://github.com/joomla/joomla-cms/pull/43676 – [4.4] Move the Cypress Tests to ESM
      if [ -f "joomla-${instance}/cypress.config.dist.js" ]; then
        extension="js"
      elif [ -f "joomla-${instance}/cypress.config.dist.mjs" ]; then
        extension="mjs"
      else
        error "No 'cypress.config.dist.*js' file found in 'joomla-${instance}' directory, please have a look."
        failed=$((failed + 1))
        overallFailed=$((overallFailed + 1))
        continue
      fi
      if [ "${actualTest}" = "system" ]; then
        # No Cypress System Tests and in 4.3 rudimentary tests fail
        if ((instance == 310 || instance < 44)); then
          # No tests executed! /  PHP Fatal error:  Uncaught Error: Call to undefined function
          log "jbt-${instance} < 44 Skipping Cypress ${actualTest} tests"
          skipped=$((skipped + 1))
          overallSkipped=$((overallSkipped + 1))
          continue
        fi
        # Is there one more argument with a test spec pattern?
        if [ -z "${spec_argument}" ]; then
          # Create spec pattern list without installation spec
          all=$(grep "tests/System/integration/" "joomla-${instance}/cypress.config.${extension}" |
            grep -v "tests/System/integration/install/" |
            tr -d "' " |
            awk '{printf "%s", $0}' |
            sed 's/,$//')
          spec="${all}"
        else
          # Use the given test spec pattern and check if we can (no pattern) and must (missing path) insert path
          if [[ "${spec_argument}" != *","* && "${spec_argument}" != tests/System/integration/* ]]; then
            spec="tests/System/integration/${spec_argument}"
          fi
        fi
      fi

      if [ "${actualTest}" = "joomla-cypress" ]; then
        if [ -z "${spec_argument}" ]; then
          spec="[cypress/joomla.cy.js,cypress/*.cy.js]"
        fi
      fi

      if [[ "${actualTest}" = "system" ]]; then
        # Run relative path tests into Joomla instance /jbt/joomla-*
        config_file="/jbt/joomla-${instance}/cypress.config.${extension}"
        cypress_dir="/jbt/joomla-${instance}"
      else
        # 'joomla-cypress'
        config_file="/jbt/installation/joomla-${instance}/cypress.config.js"
        cypress_dir="/jbt/installation/joomla-cypress"
      fi

      # For joomla-cypress you can set CYPRESS_SKIP_INSTALL_LANGUAGES=1
      # to skip installLanguage() and installJoomlaMultilingual() tests. Default here to run the tests.
      CYPRESS_SKIP_INSTALL_LANGUAGES=${CYPRESS_SKIP_INSTALL_LANGUAGES:-0}

      # 16 September 2024 disabled, because Error: Unwanted PHP Deprecated
      # # Temporarily disable Joomla logging as System Tests are failing.
      # log "jbt-${instance} – Temporarily disable Joomla logging"
      # docker exec "jbt-${instance}" bash -c "cd /var/www/html && sed \
      #   -e 's/\$debug = .*/\$debug = false;/' \
      #   -e 's/\$log_everything = .*/\$log_everything = 0;/' \
      #   -e 's/\$log_deprecated = .*/\$log_deprecated = 0;/' \
      #   configuration.php > configuration.php.tmp && \
      #   mv configuration.php.tmp configuration.php"

      if [[ "$novnc" == true ]]; then
        log "jbt-${instance} – Initiating ${actualTest} tests with NoVNC and ${spec}"
        # Using 'CYPRESS_specPattern' and not '--spec' to have absolute paths work correctly.
        docker exec jbt-cypress sh -c "cd '${cypress_dir}' && export DISPLAY=jbt-novnc:0 && \
          CYPRESS_SKIP_INSTALL_LANGUAGES=$CYPRESS_SKIP_INSTALL_LANGUAGES \
          CYPRESS_CACHE_FOLDER=/jbt/cypress-cache CYPRESS_specPattern='${spec}' ${eel1} \
          npx cypress run --headed ${browser} --config-file '${config_file}'"
      else
        log "jbt-${instance} – Initiating headless ${actualTest} tests with ${spec}"
        docker exec jbt-cypress sh -c "cd '${cypress_dir}' && unset DISPLAY && \
          CYPRESS_SKIP_INSTALL_LANGUAGES=$CYPRESS_SKIP_INSTALL_LANGUAGES \
          CYPRESS_CACHE_FOLDER=/jbt/cypress-cache CYPRESS_specPattern='${spec}' ${eel1} \
          npx cypress run ${browser} --config-file '${config_file}'"
      fi
      # shellcheck disable=SC2181 # Check either Cypress headed or headless status
      if [ $? -eq 0 ]; then
        # Don't use ((successful++)) as it returns 1 and the script fails with -e on Windows WSL Ubuntu
        successful=$((successful + 1))
        overallSuccessful=$((overallSuccessful + 1))
        log "jbt-${instance} – ${actualTest} tests passed successfully"
      else
        failed=$((failed + 1))
        overallFailed=$((overallFailed + 1))
        error "jbt-${instance} – ${actualTest} tests failed."
      fi

      # 16 September 2024 disabled, because Error: Unwanted PHP Deprecated
      # Enable Joomla logging
      # log "jbt-${instance} – Re-enabling Joomla logging"
      # docker exec "jbt-${instance}" bash -c "cd /var/www/html && sed \
      #   -e 's/\$debug = .*/\$debug = true;/' \
      #   -e 's/\$log_everything = .*/\$log_everything = 1;/' \
      #   -e 's/\$log_deprecated = .*/\$log_deprecated = 1;/' \
      #   configuration.php > configuration.php.tmp && \
      #   mv configuration.php.tmp configuration.php"
    fi
  done

  if [ ${failed} -eq 0 ]; then
    log "jbt-${instance} – Test run completed: ${successful} test(s) passed ${spec} (${skipped} skipped)"
  else
    error "jbt-${instance} – Test run completed: ${failed} test(s) failed, ${successful} test(s) passed ${spec} (${skipped} skipped)."
  fi

done

if [ ${#instancesToTest[@]} -gt 1 ]; then
  if [ ${overallFailed} -eq 0 ]; then
    log "${instancesToTest[*]} – All tests completed: ${overallSuccessful} test(s) successful ${spec} (${overallSkipped} skipped)"
    exit 0
  else
    error "${instancesToTest[*]} – All tests completed: ${overallFailed} test(s) failed, ${overallSuccessful} test(s) passed ${spec} (${overallSkipped} skipped)."
    exit 1
  fi
fi
