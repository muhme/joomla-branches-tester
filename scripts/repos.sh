#!/bin/bash -e
#
# repos.sh - Inside web server container collect all Git repositories infos. Called by 'scripts/info'.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if ! [ -f /.dockerenv ] && ! [ -f /run/.containerenv ]; then
  echo "*** Error: Please run in Docker container, e.g. docker exec jbt-44 /jbt/scripts/repos.sh joomla-44." >&2
  exit 1
fi
if [ "${JBT_INTERNAL}" != "42" ]; then
  echo "*** Error: This script is intended to be called only from 'scripts/info'." >&2
  exit 1
fi
if [[ $# -ne 1 || "$1" != joomla-* ]]; then
  echo "*** Error: Please provide branch directory name, e.g. joomla-44." >&2
  exit 1
fi
branch_dir="$1"

for git_dir in $(find . -name ".git" | sed -e 's|^.||' -e 's|.git$||' ); do
    abs_git_dir=$(echo "/var/www/html${git_dir}" | sed 's|/$||')
    if ! git config --global --get-all safe.directory | grep -q "^${abs_git_dir}$"; then
      git config --global --add safe.directory "${abs_git_dir}"
    fi
    cd "${abs_git_dir}"
    echo "  Git Repository ${branch_dir}${git_dir}"
    echo "    Remote Origin: $(git config --get remote.origin.url)"

    # joomla-39 has git version 2.20 w/o --show-current option and fails
    # -> simple ignore here as 3.9.* will not be installed from branch
    current_branch=$(git branch --show-current 2>/dev/null || true)
    if [ -n "${current_branch}" ]; then
          echo -n "    Branch: ${current_branch}"
    else
      tag_name=$(git describe --tags)
      if [ -n "${tag_name}" ]; then
        echo -n "    Tag: ${tag_name}"
      else
        echo -n "    Unknown Branch/Tag"
      fi
    fi

    for branch in $(git branch | sed 's|^* ||' ); do
      if [[ "${branch}" = jbt-pr-* ]]; then
        if [ "${git_dir}" = "/" ]; then
          repo="joomla-cms"
        else
          repo=$(basename "${git_dir}")
        fi
        echo -n " ${branch}" | sed "s|jbt-pr|${repo}|"
      fi
    done
    echo ""
    echo "    Status: $(git status -s | grep -c -v \
        -e 'tests/System/integration/install/Installation.cy.js' \
        -e 'cypress.config.local.mjs' \
        -e '.php-cs-fixer.dist.php' \
        -e 'ruleset.xml' | tr -d ' ') changes"
done
