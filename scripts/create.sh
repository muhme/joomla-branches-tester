#!/bin/bash -e
#
# create.sh - Create Docker containers based on Joomla Git branches.
#   create.sh
#   create.sh 51 pgsql socket no-cache
#   create.sh 52 53 php8.1
#   create.sh 52 https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

function help {
    echo "
    create.sh – Create base Docker containers and containers based on Joomla Git branches.
                Optional Joomla version can be one or more of the following: ${allVersions[@]} (without version, all are installed).
                Optional database variant can be one of: ${JBT_DB_VARIANTS[@]} (default is mariadbi).
                Optional 'socket' for using the database with a Unix socket (default is using TCP host).
                Optional 'IPv6' can be set (default is to use IPv4).
                Optional 'no-cache' can be set (default is to use cache).
                Optional PHP version can be one of: ${JBT_PHP_VERSIONS[@]} (default is php8.1).
                Optional 'repository:branch', e.g. https://github.com/Elfangor93/joomla-cms:mod_community_info.

                $(random_quote)
    "
}

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

# Defauls to use MariaDB with MySQLi database driver, to use cache and PHP 8.1.
database_variant="mariadbi"
socket=false
network="IPv4"
no_cache=false
php_version="php8.1"
versionsToInstall=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
  elif [ "$1" = "socket" ]; then
    socket=true
    shift # Argument is eaten as use database vwith socket.
  elif isValidVariant "$1"; then
    database_variant="$1"
    shift # Argument is eaten as database variant.
  elif [ "$1" = "IPv6" ]; then
    network="IPv6"
    shift # Argument is eaten as IPv6 option.
  elif [ "$1" = "no-cache" ]; then
    no_cache=true
    shift # Argument is eaten as no cache option.
  elif isValidPHP "$1"; then
    php_version="$1"
    shift # Argument is eaten as PHP version.
  elif [[ "$1" == *:* ]]; then
    # Split into repository and branch.
    arg_repository="${1%:*}" # remove everything after the last ':'
    arg_branch="${1##*:}" # everythin after the last ':'
    shift # Argument is eaten as repository:branch.
  else
    help
    error "Argument '$1' is not valid."
    exit 1
  fi
done

# Zeroth check host.docker.internal entry
HOSTS_FILE="/etc/hosts"
if grep -Eq "127.0.0.1[[:space:]]+host.docker.internal" "$HOSTS_FILE"; then
  log "Entry '127.0.0.1 host.docker.internal' already exists in the file '${HOSTS_FILE}'"
else
  log "Adding entry '127.0.0.1 host.docker.internal' to the file '${HOSTS_FILE}'."
  sudo sh -c "echo '127.0.0.1 host.docker.internal' >> $HOSTS_FILE"
  if ! grep -Eq "127.0.0.1[[:space:]]+host.docker.internal" "$HOSTS_FILE"; then
    error "Please add entry '127.0.0.1 host.docker.internal' to the file '${HOSTS_FILE}'."
    exit 1
  fi
fi

if [ ! -z "${git_repository}" ] && [ ${#versionsToInstall[@]} -ne 1 ]; then
  error "If you use repository:branch, please specify one version as one of the following: ${allVersions[@]}."
  exit 1
fi

# If no version was given, use all.
if [ ${#versionsToInstall[@]} -eq 0 ]; then
  versionsToInstall=(${allVersions[@]})
fi

# Delete all docker containters and branches_* directories.
scripts/clean.sh

# Create Docker Compose setup with Joomla web servers for all versions to be installed.
log "Create 'docker-compose.yml' file for version(s) ${versionsToInstall[*]}, based on ${php_version} and ${network}."
createDockerComposeFile "${versionsToInstall[*]}" "${php_version}" "${network}"

if $no_cache; then
  log "Running 'docker compose build --no-cache'."
  docker compose build --no-cache
fi

log "Running 'docker compose up'."
docker compose up -d

# Wait until MySQL database is up and running
# (This isn't accurate when using MariaDB or PostgreSQL, but so far it's working with the delay from MySQL.)
MAX_ATTEMPTS=60
attempt=1
until docker exec jbt_mysql mysqladmin ping -h"127.0.0.1" --silent || [ $attempt -eq $MAX_ATTEMPTS ]; do
  log "Waiting for MySQL to be ready, attempt $attempt of $MAX_ATTEMPTS."
  attempt=$((attempt + 1))
  sleep 1
done
# If the MAX_ATTEMPTS are exceeded, simply try to continue.

# For the tests we need mysql user/password login
log "jbt_${version} – Enable MySQL user root login with password."
docker exec -it jbt_mysql mysql -uroot -proot -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';"
# And for MariaDB too
log "jbt_${version} – Enable MariaDB user root login with password."
docker exec -it jbt_madb mysql -uroot -proot -e  "ALTER USER 'root'@'%' IDENTIFIED BY 'root';"
# And Postgres (which have already user postgres with SUPERUSER, but to simplify we will use same user root on postgres)
log "jbt_${version} – Create PostgreSQL user root with password root and SUPERUSER role."
docker exec -it jbt_pg sh -c "\
  psql -U postgres -c \"CREATE USER root WITH PASSWORD 'root';\" && \
  psql -U postgres -c \"ALTER USER root WITH SUPERUSER;\""

for version in "${versionsToInstall[@]}"; do
  # If the copying has not yet been completed, then we have to wait, or we will get e.g.
  # rm: cannot remove '/var/www/html/libraries/vendor': Directory not empty.
  max_retries=120
  for ((i = 1; i < $max_retries; i++)); do
    docker logs "jbt_${version}" 2>&1 | grep 'This server is now configured to run Joomla!' && break || {
      log "Waiting for original Joomla installation, attempt ${i} of ${max_retries}."
      sleep 1
    }
  done
  if [ $i -ge $max_retries ]; then
    error "Failed after $max_retries attempts. Giving up."
    exit 1
  fi
  log "jbt_${version} – Deleting original Joomla installation."
  docker exec -it "jbt_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  # Move away the disabled PHP error logging.
  log "jbt_${version} – Configure to display PHP warnings."
  docker exec -it "jbt_${version}" bash -c 'mv /usr/local/etc/php/conf.d/error-logging.ini /usr/local/etc/php/conf.d/error-logging.ini.DISABLED'

  # Create two PHP environments: one with Xdebug and one without.
  # Manage them by cloning /usr/local, and use symbolic links to toggle between the two installations.
  log "jbt_${version} – Configure 'php.ini' for development and set up parallel installation with Xdebug."
  docker exec -it "jbt_${version}" bash -c ' \
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini &&
    cp -r /usr/local /usr/local-without-xdebug &&
    pecl install xdebug && \
    docker-php-ext-enable xdebug'
  xdebug_path=$(docker exec -it "jbt_${version}" bash -c 'find /usr/local/lib/php/extensions/ -name "xdebug.so" | head -n 1')
  docker exec -it "jbt_${version}" bash -c "
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
  docker exec -it "jbt_${version}" bash -c ' \
    mv /usr/local /usr/local-with-xdebug && \
    ln -s /usr/local-without-xdebug /usr/local'
  # Apache is not restarted because /var/www/html is then in use, and would cause the following git clone to fail.

  log "jbt_${version} – Installing additional packages."
  docker exec -it "jbt_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y git unzip vim nodejs iputils-ping iproute2 telnet net-tools'
    # Aditional having vim, ping, netstat

  branch=$(branchName "${version}")
  if [ -z "${arg_repository}" ]; then
    git_repository="https://github.com/joomla/joomla-cms"
    git_branch="${branch}"
  else
    git_repository="$arg_repository"
    git_branch="${arg_branch}"
  fi
  log "jbt_${version} – Cloning ${git_repository}:${git_branch} into the 'branch_${version}' directory."
  docker exec -it "jbt_${version}" bash -c "git clone -b ${git_branch} --depth 1 ${git_repository} /var/www/html"

  if [ "$version" -ge 51 ]; then
    log "jbt_${version} – Installing missing libraries."
    docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
      apt-get install -y libzip4 libmagickwand-6.q16-6 libmemcached11"
  fi

  log "jbt_${version} – Running composer install."
  docker exec "jbt_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    cp -p /usr/local/bin/composer /usr/local-with-xdebug/bin/composer"
  docker exec  "jbt_${version}" bash -c "cd /var/www/html && composer install" ||
    ( log 'composer install failed on the first attempt; give it a second try.' && \
      docker exec  "jbt_${version}" bash -c "cd /var/www/html && composer install" )
    # There is a race condition (perhaps with the parallel downloads), some times composer install fails:
    # "Failed to open directory: No such file or directory"
    # As the second run was always successful, we try it directly.

  log "jbt_${version} – Running npm clean install."
  docker exec -it "jbt_${version}" bash -c 'cd /var/www/html && npm ci'

  # Needed on Windows WSL2 Ubuntu to be able to run Joomla Web Installer
  log "jbt_${version} – Changing ownership to www-data for all files and directories."
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec -it "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

  # Joomla container needs to be restarted
  log "jbt_${version} – Restarting container."
  docker restart "jbt_${version}"

  # Configure and install Joomla with desired database variant
  if $socket; then
    scripts/database.sh "${version}" "${database_variant}" "socket"
  else
    scripts/database.sh "${version}" "${database_variant}"
  fi

  log "jbt_${version} – Set container prompt"
  docker exec "jbt_${version}" bash -c "echo PS1=\'jbt_${version} \# \' >> ~/.bashrc" || true # Who cares?
done

log "Creating File '.vscode/launch.json' for versions ${versionsToInstall[*]}"
launch_json=".vscode/launch.json"
mkdir -p $(dirname "${launch_json}")
cat > "${launch_json}" <<EOF
{
    "version": "0.2.0",
    "configurations": [
EOF
for version in "${versionsToInstall[@]}"; do
  cat >> "${launch_json}" <<EOF
      {
          "name": "Listen jbt_${version}",
          "type": "php",
          "request": "launch",
          "port": 79${version},
          "pathMappings": {
              "/var/www/html": "\${workspaceFolder}/branch_${version}"
          }
      },
EOF
done
cat >> "${launch_json}" <<EOF
    ]
}
EOF

log "Installing vim, ping, ip, telnet and netstat in the 'jbt_cypress' container."
docker exec -it jbt_cypress sh -c "apt-get update && apt-get install -y git vim iputils-ping iproute2 telnet net-tools"

log "Add bash for Alpine containers"
for container in "jbt_pga" "jbt_mail"; do
  docker exec -u root ${container} apk add bash || true # Who cares?
done
log "Set container prompts for base containers"
for container in "${JBT_BASE_CONTAINERS[@]}"; do
  docker exec -u root "${container}" sh -c  \
    "echo PS1=\'${container} \# \' >> ~/.bashrc" || true # Who cares?
done
