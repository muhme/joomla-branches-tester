#!/bin/bash
#
# scripts/shellcheck.sh - Linting all all bash scripts, see https://www.shellcheck.net.
#
# Needs ShellCheck installed:
#   sudo apt-get install shellcheck   # Ubuntu
#   brew install shellcheck           # macOS
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

find scripts -type f | grep -v -e .md -e .py | while read -r file; do
    echo "FILE ${file}"
    shellcheck -x "${file}"
done
