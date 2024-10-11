#!/bin/bash
#
# scripts/shellcheck.sh - Linting all all bash scripts. Needs ShellCheck installed, see https://www.shellcheck.net.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

find scripts -type f | grep -v \
  -e pgpass \
  -e servers.json \
  -e error-logging.ini \
  -e disableBC.cy.js \
  -e patchtester.cy.js \
  -e README.md \
  -e smtp_multi_relay.py | while read -r file; do
    echo "FILE ${file}"
    shellcheck -x "${file}"
done
