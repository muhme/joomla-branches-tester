#!/bin/bash -e
#
# create.sh - Delete all docker containers, build them new and install Joomla from the git branches.
#   create.sh
#   create.sh 51 pgsql no-cache
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester


source scripts/helper.sh

# Zeroth check host.docker.internal entry
HOSTS_FILE="/etc/hosts"
if grep -Eq "127.0.0.1[[:space:]]+host.docker.internal" "$HOSTS_FILE"; then
  log "Entry '127.0.0.1 host.docker.internal' exists in file '${HOSTS_FILE}' - thx :)"
else
  error "Entry '127.0.0.1 host.docker.internal' is missing in file '${HOSTS_FILE}' - try to add"
  sudo sh -c "echo '127.0.0.1 host.docker.internal' >> $HOSTS_FILE"
  if grep -Eq "127.0.0.1[[:space:]]+host.docker.internal" "$HOSTS_FILE"; then
    log "Entry '127.0.0.1 host.docker.internal' added in file '${HOSTS_FILE}'"
  else
    error "Entry '127.0.0.1 host.docker.internal' is missing in file '${HOSTS_FILE}' - please add"
    exit 1
  fi
fi

# Defaults to install for all branches, but a single one can be given
versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}")); unset IFS # map to array
versionsToInstall=(${allVersions[@]})

if [ $# -ge 1 ] ; then
  if isValidVersion "$1" "$versions"; then
    versionsToInstall=($1)
    shift # 1st arg is eaten as the version number
  fi
fi

# Defauls to use MariaDB with MySQLi database driver, but different one can be given
database_variant="mariadbi"
if [ $# -ge 1 ] && [ "$1" != "no-cache" ] ; then
  if isValidVariant "$1"; then
    database_variant=($1)
    shift # argument is eaten as database variant
  else
    error "'$1' is not a valid selection for database and database driver, use one of ${JBT_DB_VARIANTS[@]}"
    exit 1
  fi
fi

# Delete all docker containters and all branches_*
scripts/clean.sh

# Compare arrays as strings
if [ "${versionsToInstall[*]}" != "${allVersions[*]}" ]; then
  # Create docker compose with only one Joomla web server
  createDockerComposeFile "${versionsToInstall[*]}" 
fi

if [ $# -eq 1 ] && [ "$1" = "no-cache" ]; then
  log "Docker compose build --no-cache"
  docker compose build --no-cache
fi

log "Docker compose up"
docker compose up -d

# Wait until MySQL database is up and running
MAX_ATTEMPTS=60
attempt=1
until docker exec jbt_mysql mysqladmin ping -h"127.0.0.1" --silent || [ $attempt -eq $MAX_ATTEMPTS ]; do
  log "Waiting for MySQL to be ready, attempt $attempt/$MAX_ATTEMPTS"
  attempt=$((attempt + 1))
  sleep 1
done

# For the tests we need mysql user/password login
log "jbt_${version} – Enable MySQL user root login with password"
docker exec -it jbt_mysql mysql -uroot -proot -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';"
# And for MariaDB too
log "jbt_${version} – Enable MariaDB user root login with password"
docker exec -it jbt_madb mysql -uroot -proot -e  "ALTER USER 'root'@'%' IDENTIFIED BY 'root';"
# And Postgres (which have already user postgres with SUPERUSER, but to simplify we will use same user root on postgres)
log "jbt_${version} – Create PostgreSQL user root with password root and SUPERUSER role"
docker exec -it jbt_pg sh -c "\
  psql -U postgres -c \"CREATE USER root WITH PASSWORD 'root';\" && \
  psql -U postgres -c \"ALTER USER root WITH SUPERUSER;\""

for version in "${versionsToInstall[@]}"; do
  # If the copying has not yet been completed, then we have to wait, or we will get e.g.
  # rm: cannot remove '/var/www/html/libraries/vendor': Directory not empty.
  max_retries=120
  for ((i = 1; i < $max_retries; i++)); do
    docker logs "jbt_${version}" 2>&1 | grep 'This server is now configured to run Joomla!' && break || {
      log "Waiting for original Joomla installation, attempt ${i}/${max_retries}"
      sleep 1
    }
  done
  if [ $i -ge $max_retries ]; then
    error "Failed after $max_retries attempts, giving up"
    exit 1
  fi
  log "jbt_${version} – Deleting orignal Joomla installation"
  docker exec -it "jbt_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  # Move away the disabled PHP error logging.
  log "jbt_${version} – Show PHP warnings"
  docker exec -it "jbt_${version}" bash -c 'mv /usr/local/etc/php/conf.d/error-logging.ini /usr/local/etc/php/conf.d/error-logging.ini.DISABLED'

  log "jbt_${version} – Installing packages"
  docker exec -it "jbt_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y git vim nodejs iputils-ping net-tools'
  # Aditional having vim, ping, netstat

  branch=$(branchName "${version}")
  log "jbt_${version} – cloning ${branch} branch into directory branch_${version}"
  docker exec -it "jbt_${version}" bash -c "git clone -b ${branch} --depth 1 https://github.com/joomla/joomla-cms /var/www/html"

  if [ "$version" = "51" ] || [ "$version" = "52" ] || [ "$version" = "60" ]; then
    log "Install missing libraries in container jbt_${version}"
    docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
      apt-get install -y libzip4 libmagickwand-6.q16-6 libmemcached11"
  fi

  log "jbt_${version} – Composer install"
  docker exec -it "jbt_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    composer install"

  log "jbt_${version} – npm clean install"
  docker exec -it "jbt_${version}" bash -c 'cd /var/www/html && npm ci'

  log "jbt_${version} – Change root ownership to www-data"
  # Following error seen on macOS, we ignore it as it does not matter, these files are 444
  # chmod: changing permissions of '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
  docker exec -it "jbt_${version}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

  # Joomla container needs to be restarted
  log "jbt_${version} – Restart container"
  docker restart "jbt_${version}"

  # Configure and install Joomla with desired database variant
  scripts/database.sh "${version}" "$database_variant"

done

log "Aditional having vim, ping and netstat in jbt_cypress container"
docker exec -it jbt_cypress sh -c "apt-get update && apt-get install -y git vim iputils-ping net-tools"

log "Work is done, you can now use scripts/tests.sh for System Tests or scripts/patchtester.sh to install Joomla Test Patcher"
