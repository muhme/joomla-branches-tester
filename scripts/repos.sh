#!/bin/bash -e
#
# repos.sh - Inside web server container collect all Git repositories infos. Called by 'scripts/info'.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if ! [ -f /.dockerenv ] && ! [ -f /run/.containerenv ]; then
  echo "*** Error: Please run in Docker container, e.g. docker exec jbt_44 /jbt/scripts/repos.sh branch_44." >&2
  exit 1
fi
if [ "${JBT_INTERNAL}" != "42" ]; then
  echo "*** Error: This script is intended to be called only from 'scripts/info'." >&2
  exit 1
fi
if [[ $# -ne 1 || "$1" != branch_* ]]; then
  echo "*** Error: Please provide branch directory name, e.g. branch_44." >&2
  exit 1
fi
branch_dir="$1"

for git_dir in $(find . -name ".git" | sed -e 's|^.||' -e 's|.git$||' ); do
    abs_git_dir=$(echo "/var/www/html${git_dir}" | sed 's|/$||')
    if ! git config --global --get-all safe.directory | grep -q "^${abs_git_dir}$"; then
      git config --global --add safe.directory "${abs_git_dir}"
    fi
    cd $abs_git_dir
    echo "  Git Repository ${branch_dir}${git_dir}"
    echo "    Remote Origin: $(git config --get remote.origin.url)"
    current_branch=$(git branch --show-current)
    echo -n "    Branch: ${current_branch}"
    for branch in $(git branch | sed 's|^* ||' ); do
      if [[ "${branch}" = jbt-pr-* ]]; then
        if [ "${git_dir}" = "/" ]; then
          repo="joomla-cms"
        else
          repo=$(basename ${git_dir})
        fi
        echo -n " ${branch}" | sed "s|jbt-pr|${repo}|"
      fi
    done
    echo ""
    echo "    Status: $(git status -s | grep -v \
        -e 'tests/System/integration/install/Installation.cy.js' \
        -e 'cypress.config.local.mjs' \
        -e '.php-cs-fixer.dist.php' \
        -e 'ruleset.xml' | wc -l | tr -d ' ') changes"
done
