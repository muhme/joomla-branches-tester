#!/bin/bash -e
#
# setup.sh - Install and configure Docker web server containers initial or after switching PHP version.
#   setup.sh 53
#   setup.sh 53 initial pgsql socket https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/setup'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    setup.sh – Internal setup the web server Docker container. Used by 'scripts/create' and 'scripts/php'.
               Mandatory Joomla version must be one of the following: ${versions}.
               Optional 'initial' for first time installation.
               Optional initial database variant can be one of: ${JBT_DB_VARIANTS[@]} (default is mariadbi).
               Optional initial 'repository:branch', e.g. https://github.com/Elfangor93/joomla-cms:mod_community_info.
               Optional initial 'socket' for using the database with a Unix socket (default is using TCP host).

               $(random_quote)
    "
}

versions=$(getVersions)
# Defaults to use MariaDB with MySQLi database driver, to use cache and PHP 8.1.
database_variant="mariadbi"
initial=false
socket=false
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "${versions}"; then
    version="$1"
    shift # Argument is eaten as onthee version number.
  elif [ "$1" = "initial" ]; then
    initial=true
    shift # Argument is eaten as to install first time.
  elif [ "$1" = "socket" ]; then
    socket=true
    shift # Argument is eaten as use database with socket.
  elif isValidVariant "$1"; then
    database_variant="$1"
    shift # Argument is eaten as database variant.
  elif [[ "$1" == *:* ]]; then
    # Split into repository and branch.
    arg_repository="${1%:*}" # remove everything after the last ':'
    arg_branch="${1##*:}"    # everything after the last ':'
    shift                    # Argument is eaten as repository:branch.
  else
    # Ignore empty strings (""), colons (":"), and any other unnecessary arguments.
    shift
  fi
done

if [ "${JBT_INTERNAL}" != "42" ]; then
  help
  error "This script is intended to be called only from 'scripts/create' or 'scripts/php'."
  exit 1
fi

if [ -z "$version" ]; then
  help
  error "Please provide one version number from ${versions}"
  exit 1
fi

log "jbt_${version} – Configure to catch all PHP errors, including notices and deprecated warnings."
docker cp scripts/error-logging.ini "jbt_${version}:/usr/local/etc/php/conf.d/error-logging.ini"

# Create two PHP environments: one with Xdebug and one without.
# Manage them by cloning /usr/local, and use symbolic links to toggle between the two installations.
log "jbt_${version} – Configure 'php.ini' for development and set up parallel installation with Xdebug."
docker exec "jbt_${version}" bash -c ' \
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini &&
    cp -r /usr/local /usr/local-without-xdebug &&
    pecl install xdebug && \
    docker-php-ext-enable xdebug'
xdebug_path=$(docker exec "jbt_${version}" bash -c 'find /usr/local/lib/php/extensions/ -name "xdebug.so" | head -n 1')
docker exec "jbt_${version}" bash -c "
cat <<EOF > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
zend_extension=${xdebug_path}
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.client_host=host.docker.internal
xdebug.client_port=79${version}
xdebug.log=/var/log/xdebug.log
xdebug.discover_client_host=true
EOF
"
docker exec "jbt_${version}" bash -c ' \
    mv /usr/local /usr/local-with-xdebug && \
    ln -s /usr/local-without-xdebug /usr/local'
# Apache is not restarted because /var/www/html is then in use, and would cause the following git clone to fail.

# Installing Node.js v22 and cron for Joomla Task Scheduler
# Additional having vim, ping, telnet, netstat for comfort
log "jbt_${version} – Installing additional packages."
docker exec "jbt_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y cron git unzip vim nodejs iputils-ping iproute2 telnet net-tools'

if $initial; then
  branch=$(branchName "${version}")
  if [ -z "${arg_repository}" ]; then
    git_repository="https://github.com/joomla/joomla-cms"
    git_branch="${branch}"
  else
    git_repository="$arg_repository"
    git_branch="${arg_branch}"
  fi
  log "jbt_${version} – Cloning ${git_repository}:${git_branch} into the 'branch_${version}' directory."
  docker exec "jbt_${version}" bash -c "git clone -b ${git_branch} --depth 1 ${git_repository} /var/www/html"
fi

if [ "$version" -ge 51 ]; then
  log "jbt_${version} – Installing missing libraries."
  docker exec "jbt_${version}" bash -c "cd /var/www/html && \
      apt-get install -y libzip4 libmagickwand-6.q16-6 libmemcached11"
fi

# Running composer install even if we are not initial - just in case.
if [ -f "branch_${version}/composer.json" ]; then
  log "jbt_${version} – Running composer install."
  docker exec "jbt_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    cp -p /usr/local/bin/composer /usr/local-with-xdebug/bin/composer"
  docker exec "jbt_${version}" bash -c "cd /var/www/html && composer install" ||
    (log 'composer install failed on the first attempt; give it a second try.' &&
      docker exec "jbt_${version}" bash -c "cd /var/www/html && composer install")
  # There is a race condition (perhaps with the parallel downloads), some times composer install fails:
  # "Failed to open directory: No such file or directory"
  # As the second run was always successful, we try it directly.
fi

if $initial; then
  # npm clean install only initial, with switching PHP version nothing changed for JavaScript
  if [ -f "branch_${version}/package.json" ]; then
    log "jbt_${version} – Running npm clean install."
    docker exec "jbt_${version}" bash -c 'cd /var/www/html && npm ci'
  fi
fi

# Needed on Windows WSL2 Ubuntu to be able to run Joomla Web Installer
log "jbt_${version} – Changing ownership to www-data for all files and directories."
# Following error seen on macOS, we ignore it as it does not matter, these files are 444
# chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
docker exec "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

# Joomla container needs to be restarted
log "jbt_${version} – Restarting container."
docker restart "jbt_${version}"

# Configure and install Joomla with desired database variant
if $initial; then
  if ${socket}; then
    scripts/database "${version}" "${database_variant}" "socket"
  else
    scripts/database "${version}" "${database_variant}"
  fi
fi

# Define the cron job entry
cronjob="* * * * * /usr/local/bin/php /var/www/html/cli/joomla.php scheduler:run --all --no-interaction --quiet || true"
# Check if the cron job already exists
if ! docker exec "jbt_${version}" bash -c "(crontab -l 2>/dev/null || echo '') | grep -F \"$cronjob\" > /dev/null"; then
  log "jbt_${version} – Adding cron job for Joomla Task Scheduler"
  docker exec "jbt_${version}" bash -c "
    ( ( crontab -l 2>/dev/null || echo "" );
    echo '# Joomla Task Scheduler, ignore exit status e.g. 127 No tasks due!';
    echo \"$cronjob\" ) | crontab -"
fi

log "jbt_${version} – Set container prompt"
docker exec "jbt_${version}" bash -c "echo PS1=\'jbt_${version} \# \' >> ~/.bashrc" || true # Who cares?
