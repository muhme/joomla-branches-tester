#!/bin/bash -e
#
# patch.sh - Apply Git patches in the repositories ‘joomla-cms’, ‘joomla-cypress’ or ‘joomla-framework/database’.
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
    patch – Apply Git patches in the repositories 'joomla-cms', 'joomla-cypress' or 'joomla-framework/database'.
            Optional Joomla version can be one or more of the following: ${allVersions[*]} (default is all).
            One or multipe patches, e.g. joomla-cms-43968, joomla-cypress-33 or database-310

            $(random_quote)
    "
}

patches=()
# shellcheck disable=SC2207 # There are no spaces in version numbers
allVersions=($(getVersions))
versionsToPatch=()

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${allVersions[*]}"; then
    versionsToPatch+=("$1")
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

# If no version was given, use all.
if [ ${#versionsToPatch[@]} -eq 0 ]; then
  versionsToPatch=("${allVersions[@]}")
fi
if [ ${#patches[@]} -eq 0 ]; then
  help
  error "Please provide at least one patch, e.g. 'joomla-cypress-33'."
  exit 1
fi

for version in "${versionsToPatch[@]}"; do

  if [ ! -d "branch_${version}" ]; then
    log "jbt-${version} – There is no directory 'branch_${version}', jumped over"
    continue
  fi

  for patch in "${patches[@]}"; do
    repo="${patch%-*}" # 'joomla-cms', 'database' or 'joomla-cypress'
    patch_number="${patch##*-}" # e.g. 43968, 31 or 33
    # Don't use "jbt-${repo_version}", use 'jbt-merged' as constant as with Git merge the repository version may change.
    merge_branch="jbt-merged"

    if [ "${repo}" = "joomla-cms" ]; then
      repo_version=$(grep '"version":' "branch_${version}/package.json" | sed -n 's/.*"version": "\([0-9.]*\)".*/\1/p')
      dir="."
      current_branch=$(docker exec "jbt-${version}" bash -c "git branch --show-current")
      if [ "${current_branch}" != "${merge_branch}" ]; then
        # Unshallow 'joomla-cms' as it was cloned with --depth 1 in setup.sh for speed and space
        log "jbt-${version} - Git unshallow '${repo}' repository"
        docker exec "jbt-${version}" git fetch --unshallow
        log "jbt-${version} - Create '${merge_branch}' branch on 'joomla-cms' repository and switch to it"
        docker exec "jbt-${version}" git checkout -b "${merge_branch}"
      fi
    elif [ "${repo}" = "database" ]; then
      dir="libraries/vendor/joomla/joomla-framework"
      repo_version=$(docker exec "jbt-${version}" bash -c "composer info joomla/database| grep versions | sed 's/versions : \* //'")
    elif [ "${repo}" = "joomla-cypress" ]; then
      dir="node_modules/joomla-projects"
      repo_version=$(docker exec "jbt-${version}" bash -c "npm list joomla-cypress | grep 'joomla-cypress@' | sed 's/.*joomla-cypress@//'")
    else
      error "Repository '${repo}' is not supported, '${patch}' patch will be ignored."
      continue
    fi

    #      dir is '.', 'libraries/vendor/joomla/joomla-framework' or 'node_modules/joomla-projects'
    # base_dir is '.', 'libraries/vendor/joomla'                  or 'node_modules'
    basedir=$(dirname "${dir}")

    # Case 0: Directory doesn't exist (don't check for joomla-cms)
    if [ "${repo}" != "joomla-cms" ] && [ ! -d "branch_${version}/${basedir}/${repo}" ]; then
      error "Missing 'branch_${version}/${basedir}/${repo}' directory, '${patch}' patch will be ignored."
      continue
    fi

    # Case 1: Clone to new Git repository and apply the patch (never for joomla-cms)
    if [ "${repo}" != "joomla-cms" ] && [ ! -d "branch_${version}/${basedir}/${repo}/.git" ]; then
      log "jbt-${version} - Delete 'branch_${version}/${basedir}/${repo}' directory"
      rm -rf "branch_${version}/${basedir}/${repo}" 2>/dev/null || sudo rm -rf "branch_${version}/${basedir}/${repo}"
      log "jbt-${version} - Git clone $(basename "${dir}")/${repo}, version ${repo_version}"
      docker exec "jbt-${version}" bash -c "
        cd ${basedir}
        git clone \"https://github.com/$(basename "${dir}")/${repo}\"
        cd ${repo}
        git checkout -b \"${merge_branch}\" \"refs/tags/${repo_version}\""
      # Merge given PR
      log "jbt-${version} - Apply PR ${patch}"
      # Using a simple Git merge (instead of a three-way diff) to apply the specific PR differences between
      # the two branches. This may introduce additional changes, but ensures the merge is possible.
      docker exec "jbt-${version}" bash -c "
        cd \"${basedir}/${repo}\"
        git fetch origin \"pull/${patch_number}/head:jbt-pr-${patch_number}\"
        git merge \"jbt-pr-${patch_number}\"
        git config --global --add safe.directory \"/var/www/html/${basedir}/${repo}\""
      continue
    elif
      # Case 2: Check if the patch has already been applied in existing Git repository.
      # TODO: ?Needed? check PR is already included in the release
      docker exec "jbt-${version}" bash -c "
        [ \"${repo}\" != \"joomla-cms\" ] && cd \"${basedir}/${repo}\"
        git fetch origin \"pull/${patch_number}/head:jbt-pr-${patch_number}\"
        git merge-base --is-ancestor \"jbt-pr-${patch_number}\" \"${merge_branch}\""; then
          log "jbt-${version} - PR '${patch}' has already been applied"
      continue
    else
      # Case 3: Apply the patch to the existing Git repository
      # Using a simple Git merge (instead of a three-way diff) to apply the specific PR differences between
      # the two branches. This may introduce additional changes, but ensures the merge is possible.
      log "jbt-${version} - Apply PR ${patch}"
      docker exec "jbt-${version}" bash -c "
        [ \"${repo}\" != \"joomla-cms\" ] && cd \"${basedir}/${repo}\"
        git merge \"jbt-pr-${patch_number}\""
      continue
    fi
  done
done
