#!/bin/bash -e
#
# patch.sh - Apply Git patches in 'joomla-cms', 'joomla-cypress' or 'joomla-framework/database'.
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/patch'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    patch – Apply Git patches in 'joomla-cms', 'joomla-cypress' or 'joomla-framework/database'.
            Mandatory Joomla version must be one of the following: ${versions}.
            One or multipe patches, e.g. joomla-cms-43968, joomla-cypress-33 or database-310

            $(random_quote)
    "
}

patches=()
versions=$(getVersions)
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${versions}"; then
    version="$1"
    shift # Argument is eaten as onthee version number.
  elif [[ "$1" =~ ^(joomla-cms|joomla-cypress|database)-[0-9]+$ ]]; then
    patches+=("$1")
    shift # Argument is eaten as one patch.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

if [ -z "$version" ]; then
  help
  error "Please provide one version number from ${versions}."
  exit 1
fi
if [ ${#patches[@]} -eq 0 ]; then
  help
  error "Please provide at least one patch, e.g. 'joomla-cypress-33'."
  exit 1
fi

for patch in ${patches[@]}; do
  repo="${patch%-*}"
  patch_number="${patch##*-}"

  if [ "${repo}" = "joomla-cms" ]; then
    repo_version=$(grep '"version":' "branch_${version}/package.json" | sed -n 's/.*"version": "\([0-9.]*\)".*/\1/p')
    dir="."
    current_branch=$(docker exec "jbt_${version}" bash -c "git branch --show-current")
    if [ "${current_branch}" != "jbt-${repo_version}" ]; then
      # Unshallow 'joomla-cms' as it was cloned with --depth 1 in setup.sh for speed and space
      log "jbt_${version} - Git unshallow '${repo}' repository"
      docker exec "jbt_${version}" git fetch --unshallow
      log "jbt_${version} - Checkout 'jbt-${repo_version}' branch on 'joomla-cms' repository"
      docker exec "jbt_${version}" git checkout -b "jbt-${repo_version}"
    fi
  elif [ "${repo}" = "database" ]; then
    dir="libraries/vendor/joomla/joomla-framework"
    repo_version=$(docker exec "jbt_${version}" bash -c "composer info joomla/database| grep versions | sed 's/versions : \* //'")
  elif [ "${repo}" = "joomla-cypress" ]; then
    dir="node_modules/joomla-projects"
    repo_version=$(docker exec "jbt_${version}" bash -c "npm list joomla-cypress | grep 'joomla-cypress@' | sed 's/.*joomla-cypress@//'")
  else
    error "Repository '${repo}' is not supported, '${patch}' patch will be ignored."
    continue
  fi

  # Case 0: Directory doesn't exist (don't check for joomla-cms)
  if [ "${repo}" != "joomla-cms" ] && [ ! -d "branch_${version}/$(dirname ${dir})/${repo}" ]; then
    error "Missing 'branch_${version}/$(dirname ${dir})/${repo}' directory, '${patch}' patch will be ignored."
    continue
  fi

  # Case 1: Clone to new Git repository and apply the patch (never for joomla-cms)
  if [ "${repo}" != "joomla-cms" ] && [ ! -d "branch_${version}/$(dirname ${dir})/${repo}/.git" ]; then
    log "jbt_${version} - Delete 'branch_${version}/$(dirname ${dir})/${repo}' directory"
    rm -rf "branch_${version}/$(dirname ${dir})/${repo}" 2>/dev/null || sudo rm -rf "branch_${version}/$(dirname ${dir})/${repo}"
    log "jbt_${version} - Git clone $(basename ${dir})/${repo}, version ${repo_version}"
    docker exec "jbt_${version}" bash -c "
      cd $(dirname ${dir})
      git clone \"https://github.com/$(basename ${dir})/${repo}\"
      cd ${repo}
      git checkout -b \"jbt-${repo_version}\" \"refs/tags/${repo_version}\"" 
    # Merge given PR
    log "jbt_${version} - Apply PR ${patch}"
    docker exec "jbt_${version}" bash -c "
      cd \"$(dirname ${dir})/${repo}\"
      git fetch origin \"pull/${patch_number}/head:jbt-pr-${patch_number}\"
      git merge \"jbt-pr-${patch_number}\"
      git config --global --add safe.directory \"/var/www/html/${dir}/${repo}\""
    continue
  elif
    # Case 2: Check if the patch has already been applied in existing Git repository.
    # TODO: ?Needed? check PR is already included in the release
    docker exec "jbt_${version}" bash -c "
      [ \"${repo}\" != \"joomla-cms\" ] && cd \"$(dirname ${dir})/${repo}\"
      git fetch origin \"pull/${patch_number}/head:jbt-pr-${patch_number}\"
      git merge-base --is-ancestor \"jbt-pr-${patch_number}\" jbt-${repo_version}"; then
      log "jbt_${version} - PR '${patch}' has already been applied"
    continue
  else
    # Case 3: Apply the patch to the existing Git repository
    log "jbt_${version} - Apply PR ${patch}"
    docker exec "jbt_${version}" bash -c "
      [ \"${repo}\" != \"joomla-cms\" ] && cd \"$(dirname ${dir})/${repo}\"
      git fetch origin \"pull/${patch_number}/head:jbt-pr-${patch_number}\"
      git merge \"jbt-pr-${patch_number}\""
    continue
  fi
done
