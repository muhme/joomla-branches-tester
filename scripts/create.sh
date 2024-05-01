#!/bin/bash -e
#
# create.sh - delete all docker containers, build them new and install Joomla from git branches
#
# MIT License, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-system-tests

source scripts/helper.sh

# First delete all docker containters
scripts/clean.sh

for version in "${VERSIONS[@]}"
do
  log "Removing directory branch_${version}"
  rm -rf "branch_${version}"
done

if [ $# -eq 1 ] && [ "$1" = "build" ] ; then
  log "Docker compose build --no-cache"
  docker compose build --no-cache
fi

log "Docker compose up"
docker compose up -d

for version in "${VERSIONS[@]}"
do
  # if the copying has not yet been completed, then we have to wait, or we will get e.g.
  # rm: cannot remove '/var/www/html/libraries/vendor': Directory not empty
  max_retries=120
  for ((i=1; i<$max_retries; i++)); do
  docker logs "jst_${version}" 2>&1 | grep 'This server is now configured to run Joomla!' && break || {
      log "Waiting for original Joomla installation, attempt ${i}/${max_retries}"
      sleep 1
    }
  done
  if [ $i -ge $max_retries ]; then
      log "Failed after $max_retries attempts, giving up"
      exit 1
  fi
  log "jst_${version} – Deleting orignal Joomla installation"
  docker exec -it "jst_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  log "jst_${version} – Installing packages"
  docker exec -it "jst_${version}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y git vim nodejs iputils-ping'

  branch=$(echo $version | sed -E 's/([0-9])([0-9])/\1.\2-dev/')
  log "jst_${version} – cloning ${branch} branch into directory branch_${version}"
  docker exec -it "jst_${version}" bash -c "git clone -b ${branch} --depth 1 https://github.com/joomla/joomla-cms /var/www/html"

  log "jst_${version} – Composer"
  docker exec -it "jst_${version}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    mv composer.phar /usr/local/bin/composer && \
    composer install"

  log "jst_${version} – npm"
  docker exec -it "jst_${version}" bash -c 'cd /var/www/html && npm ci'

  log "jst_${version} – create cypress.config.js"
  # adopt e.g.:
  #   >     db_name: 'test_joomla_44'
  #   >     db_prefix: 'jos44_',
  #   >     db_host: 'mysql',
  #   >     baseUrl: 'http://host.docker.internal:7044',
  #   >     db_password: 'root',
  docker exec -it "jst_${version}" bash -c "cd /var/www/html && sed \
    -e \"s/db_name: .*/db_name: 'test_joomla_${version}',/\" \
    -e \"s/db_prefix: .*/db_prefix: 'jos${version}_',/\" \
    -e \"s/db_host: .*/db_host: 'mysql',/\" \
    -e \"s/baseUrl: .*/baseUrl: 'http:\/\/host.docker.internal:70${version}\/',/\" \
    -e \"s/db_password: .*/db_password: 'root',/\" \
    cypress.config.dist.js > cypress.config.js"

  log "jst_${version} – Cypress based Joomla installation"
  # Joomla container needs to be restarted
  docker stop "jst_${version}"
  docker start "jst_${version}"
  docker exec -it jst_cypress sh -c "cd /branch_${version} && cypress run --spec tests/System/integration/install/Installation.cy.js"

  # for the tests we need mysql user/password login
  log "jst_${version} – Enable MySQL user root login with password"
  docker exec -it jst_mysql mysql -uroot -proot -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';"
done
