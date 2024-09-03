#!/bin/bash -e
#
# create.sh - Create Docker containers based on Joomla Git branches.
#   create.sh
#   create.sh 51 pgsql no-cache
#   create.sh 52 53 php8.1
#   create.sh 52 https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

source scripts/helper.sh

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

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array

# Defauls to use MariaDB with MySQLi database driver, to use cache and PHP 8.1.
database_variant="mariadbi"
no_cache=false
php_version="php8.1"
versionsToInstall=()
while [ $# -ge 1 ]; do
  if isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
  elif isValidVariant "$1"; then
    database_variant="$1"
    shift # Argument is eaten as database variant.
  elif [ "$1" = "no-cache" ]; then
    no_cache=true
    shift # Argument is eaten as no cache option.
  elif isValidPHP "$1"; then
    php_version="$1"
    shift # Argument is eaten as PHP version.
  elif [[ "$1" == *:* ]]; then
    # Split into repository and branch.
    git_repository="${1%:*}" # remove everything after the last ':'
    git_branch="${1##*:}" # everythin after the last ':'
    shift # Argument is eaten as repository:branch.
  else
    log "Optional Joomla version can be one or more of the following: ${allVersions[@]} (default is all)."
    log "Optional database variant can be one of: ${JBT_DB_VARIANTS[@]} (default is mariadbi)."
    log "Optional no-cache can be set (default is to use cache)."
    log "Optional PHP version can be one of: ${JBT_PHP_VERSIONS[@]} (default is php8.1)."
    log "Optional repository:branch, e.g. https://github.com/Elfangor93/joomla-cms:mod_community_info."
    error "Argument '$1' is not valid."
    exit 1
  fi
done

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
createDockerComposeFile "${versionsToInstall[*]}" "$php_version"

if [ $# -eq 1 ] && [ "$1" = "no-cache" ]; then
  log "Running 'docker compose build --no-cache'."
  docker compose build --no-cache
fi

log "Running 'docker compose up'."
docker compose up -d

# Wait until MySQL database is up and running
MAX_ATTEMPTS=60
attempt=1
until docker exec jbt_mysql mysqladmin ping -h"127.0.0.1" --silent || [ $attempt -eq $MAX_ATTEMPTS ]; do
  log "Waiting for MySQL to be ready, attempt $attempt of $MAX_ATTEMPTS."
  attempt=$((attempt + 1))
  sleep 1
done

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
  log "jbt_${version} – Deleting orignal Joomla installation."
  docker exec -it "jbt_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  # Move away the disabled PHP error logging.
  log "jbt_${version} – Configure to display PHP warnings."
  docker exec -it "jbt_${version}" bash -c 'mv /usr/local/etc/php/conf.d/error-logging.ini /usr/local/etc/php/conf.d/error-logging.ini.DISABLED'

  log "jbt_${version} – Installing additional packages."
  docker exec -it "jbt_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y git unzip vim nodejs iputils-ping iproute2 telnet net-tools'
  # Aditional having vim, ping, netstat

  branch=$(branchName "${version}")
  if [ -z "${git_repository}" ]; then
    git_repository="https://github.com/joomla/joomla-cms"
    git_branch="${branch}"
  fi
  log "jbt_${version} – Cloning ${git_repository}:${git_branch} into the 'branch_${version}' directory."
  docker exec -it "jbt_${version}" bash -c "git clone -b ${git_branch} --depth 1 ${git_repository} /var/www/html"

  if [ "$version" -ge 51 ]; then
    log "jbt_${version} – Installing missing libraries."
    docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
      apt-get install -y libzip4 libmagickwand-6.q16-6 libmemcached11"
  fi

  log "jbt_${version} – Running composer install."
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    composer install"

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
  scripts/database.sh "${version}" "$database_variant"

  log "jbt_${version} – Set container prompt"
  docker exec "jbt_${version}" bash -c "echo PS1=\'jbt_${version} \# \' >> ~/.bashrc" || true # Who cares?
done

log "Installing vim, ping, ip, telnet and netstat in the 'jbt_cypress' container."
docker exec -it jbt_cypress sh -c "apt-get update && apt-get install -y git vim iputils-ping iproute2 telnet net-tools"

log "Add bash in Alpine containers"
for container in "jbt_pga" "jbt_mail"; do
  docker exec -u root ${container} apk add bash || true # Who cares?
done
log "Set container prompts for base containers"
for container in "${JBT_BASE_CONTAINERS[@]}"; do
  docker exec -u root "${container}" sh -c  \
    "echo PS1=\'${container} \# \' >> ~/.bashrc" || true # Who cares?
done
