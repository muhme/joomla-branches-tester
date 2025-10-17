#!/bin/bash -e
#
# create.sh - Create Docker containers based on Joomla Git branches.
#   create
#   create 51 pgsql socket
#   create 52 53 php8.1 recreate
#   create 52 https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/create'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  local valid_versions_without_highest=("${JBT_VALID_PHP_VERSIONS[@]:0:${#JBT_VALID_PHP_VERSIONS[@]}-1}")

  echo "
    create – Creates the base and creates or recreates Joomla web server Docker containers.
             One or more optional Joomla version(s), if not specified, ${JBT_ALL_USED_BRANCHES[*]} are used
               or use 'all' for: ${JBT_HIGHEST_VERSION[*]}.
               See 'scripts/versions' for all usable versions.
             The optional database variant can be one of: ${JBT_DB_VARIANTS[*]} (default is mariadbi).
             The optional 'socket' argument configures database access via Unix socket (default is TCP host).
             The optional 'IPv6' argument enables support for IPv6 (default is IPv4).
             The optional 'recreate' argument creates or recreates specified Joomla web server containers.
             The optional PHP version can be set to one of: ${valid_versions_without_highest[*]} (default is highest).
             The optional 'repository:branch' argument (default repository is https://github.com/joomla/joomla-cms).
             Optionally specify one or more patches (e.g., 'joomla-cypress-36'; default is unpatched).
             The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

# Wait until MySQL database is up and running
#
function waitForMySQL {
  MAX_ATTEMPTS=60
  attempt=1
  until docker exec jbt-mysql mysqladmin ping -h"127.0.0.1" --silent || [ $attempt -eq $MAX_ATTEMPTS ]; do
    log "Waiting for MySQL to be ready, attempt $attempt of $MAX_ATTEMPTS"
    attempt=$((attempt + 1))
    sleep 1
  done
  # If the MAX_ATTEMPTS are exceeded, simply try to continue.
}

# Defaults to use MariaDB with MySQLi database driver, to use cache and PHP 8.1.
database_variant="mariadbi"
socket=""
network="IPv4"
recreate=false
php_version="highest"
versionsToInstall=()
unpatched=false
patches=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1"; then
    versionsToInstall+=("$(fullName "$1")")
    shift # Argument is eaten as one version number.
  elif [ "$1" = "all" ]; then
    versionsToInstall=("${JBT_HIGHEST_VERSION[@]}")
    shift # Argument is eaten as all versions to install.
  elif [ "$1" = "socket" ]; then
    socket="socket"
    shift # Argument is eaten as use database with socket.
  elif [ "$1" = "recreate" ]; then
    recreate=true
    shift # Argument is eaten as option recreate.
  elif isValidVariant "$1"; then
    database_variant="$1"
    shift # Argument is eaten as database variant.
  elif [ "$1" = "IPv6" ]; then
    network="IPv6"
    shift # Argument is eaten as IPv6 option.
  elif isValidPHP "$1"; then
    php_version="$1"
    shift # Argument is eaten as PHP version.
  elif [[ "$1" == *:* ]]; then
    # Split into repository and branch.
    arg_repository="${1%:*}" # remove everything after the last ':'
    arg_branch="${1##*:}"    # everything after the last ':'
    shift                    # Argument is eaten as repository:branch.
  elif [ "$1" = "unpatched" ]; then
    unpatched=true
    shift # Argument is eaten as unpatched option.
  elif [[ "$1" =~ ^(joomla-cms|joomla-cypress|database)-[0-9]+$ ]]; then
    patches+=("$1")
    shift # Argument is eaten as a patch.
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
  log "Adding entry '127.0.0.1 host.docker.internal' to the file '${HOSTS_FILE}'"
  sudo sh -c "echo '127.0.0.1 host.docker.internal' >> $HOSTS_FILE"
  if ! grep -Eq "127.0.0.1[[:space:]]+host.docker.internal" "$HOSTS_FILE"; then
    error "Please add entry '127.0.0.1 host.docker.internal' to the file '${HOSTS_FILE}'."
    exit 1
  fi
fi

if [ -n "${git_repository}" ] && [ ${#versionsToInstall[@]} -ne 1 ]; then
  error "If you use repository:branch, please specify one Joomla version."
  exit 1
fi

if [ "$recreate" = true ] && [ ! -f docker-compose.yml ]; then
  error "The 'recreate' option was given, but no 'docker-compose.yml' file exists. Please run 'scripts/create' first."
  exit 1
fi

# If no version was given, use all.
if [ ${#versionsToInstall[@]} -eq 0 ]; then
  versionsToInstall=("${JBT_ALL_USED_BRANCHES[@]}")
fi

if [ "$unpatched" = true ]; then
  patches=("unpatched")
elif [ ${#patches[@]} -eq 0 ]; then
  patches=("${JBT_DEFAULT_PATCHES[@]}")
fi
# else: patches are already filled in the array

if [ "$recreate" = false ]; then

  # Delete all docker containers and branches_* directories.
  scripts/clean.sh

  # Create Docker Compose setup with Joomla web servers for all versions to be installed.
  log "Create 'docker-compose.yml' file for version(s) ${versionsToInstall[*]}, based on ${php_version} PHP version and ${network}"
  createDockerComposeFile "${versionsToInstall[*]}" "${php_version}" "${network}"

  # Make sure all bind source folders exist on the HOST (prevents ghost mounts)
  for version in "${versionsToInstall[@]}"; do
    instance=$(getMajorMinor "${version}")
    mkdir -p "joomla-${instance}" "installation/joomla-${instance}"
  done

  log "Running 'docker compose build --no-cache'"
  # Always attempt to pull a newer version of the image, to have latest for e.g. pgadmin4:latest
  # Always use no cache as we have too often seen problems with
  # volume shadowing and stale mounts from deleted containers, e.g.
  # "mkdir: cannot create directory '/jbt/installation/joomla-39': File exists"
  docker compose build --pull --no-cache

  log "Running 'docker compose up'"
  docker compose up -d
fi

# Wait until MySQL database is up and running
# (This isn't accurate when using MariaDB or PostgreSQL, but so far it's working with the delay from MySQL.)
waitForMySQL

if [ "$recreate" = false ]; then

  # Disable MySQL binary logging to prevent waste of space
  # see https://github.com/joomla-docker/docker-joomla/issues/197
  log "Disable MySQL binary logging"
  docker exec jbt-mysql bash -c "sed -i '/^\[mysqld\]/a skip-log-bin' '/etc/my.cnf'"
  docker restart jbt-mysql
  waitForMySQL

  # For the tests we need old-school user/password login, once over TCP and once for localhost with Unix sockets
  log "Enable MySQL user root login with password"
  docker exec jbt-mysql mysql -uroot -proot \
    -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root';"
  # And for MariaDB too
  log "Enable MariaDB user root login with password"
  docker exec jbt-madb mysql -uroot -proot \
    -e "ALTER USER 'root'@'%' IDENTIFIED BY 'root';" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"
  # And Postgres (which have already user postgres with SUPERUSER, but to simplify we will use same user root on postgres)
  log "Create PostgreSQL user root with password root and SUPERUSER role"
  docker exec jbt-pg sh -c "\
  psql -U postgres -c \"CREATE USER root WITH PASSWORD 'root';\" && \
  psql -U postgres -c \"ALTER USER root WITH SUPERUSER;\""
fi

# Performing additional version-independent configurations to complete the base installation.
if [ "$recreate" = false ]; then
  log "jbt-cypress – Installing git, vim, ping, ip, telnet and netstat"
  # 17 February 2025 "apt-get update" Error "Missing Google Chrome GPG Key" with current cypress/included image
  #   -> Add the missing key manually and update Chrome repo before "apt-get update"
  #      -> this needs pgp and curl
  #         -> this needs "apt-get update" before, even if it fails
  #   -> and the next two "apt-get install" can not be have "apt-get update" before, as the key is then loosed
  #   -> but the last "apt-get install php ..." needs error-ignored "apt-get update" before :(
  # to be checked later if this is still needed
  docker exec jbt-cypress sh -c "apt-get update >/dev/null 2>&1; apt-get install gpg curl -y && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /usr/share/keyrings/google-chrome.gpg > /dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb stable main' | tee /etc/apt/sources.list.d/google-chrome.list && \
    apt-get install -y git vim iputils-ping iproute2 telnet net-tools"

  log "jbt-cypress – Creating and importing SSL certificates"
  mkdir -p installation/certs
  docker exec jbt-cypress sh -c "
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /jbt/installation/certs/self.key \
            -out /jbt/installation/certs/self.crt -subj '/CN=localhost/O=JBT' \
            -addext "subjectAltName=DNS:localhost,DNS:host.docker.internal,IP:127.0.0.1" \
            -addext "keyUsage=digitalSignature,keyEncipherment" \
            -addext "extendedKeyUsage=serverAuth" && \
    cp /jbt/installation/certs/self.crt /usr/local/share/ca-certificates && \
    update-ca-certificates"

  log "jbt-cypress – JBT 'installation' environment – installing cypress@${JBT_INSTALLATION_CYPRESS_VERSION}"
  # We install now, but don't delete pre-installed Cypress with rm -rf /root/.cache/Cypress
  cypress_installation="${CYPRESS_CACHE_FOLDER}/${JBT_INSTALLATION_CYPRESS_VERSION}"
  docker exec "jbt-cypress" bash -c "cd /jbt/installation && \
                                     npm install cypress-file-upload cypress@${JBT_INSTALLATION_CYPRESS_VERSION} && \
                                     export CYPRESS_CACHE_FOLDER=/jbt/cypress-cache && \
                                     if [ -d ${cypress_installation} ]; then \
                                       echo 'CONTAINER jbt-cypress: ${cypress_installation} already exists.'; \
                                     elif [ -d /root/.cache/${JBT_INSTALLATION_CYPRESS_VERSION} ]; then \
                                       echo 'CONTAINER jbt-cypress: Reusing Cypress binary from image'; \
                                       mv /root/.cache/${JBT_INSTALLATION_CYPRESS_VERSION} ${cypress_installation}; \
                                     else \
                                       echo 'CONTAINER jbt-cypress: Running npx cypress install'; \
                                       npx cypress install; \
                                     fi"

  # JBT Cypress Installation Environment
  log "jbt-cypress – Adding 'installation/joomla-cypress' module as a Git shallow clone of the main branch"
  docker exec "jbt-cypress" bash -c "cd /jbt/installation && \
                                     git clone --depth 1 https://github.com/joomla-projects/joomla-cypress"

  # Browsers are not preinstalled for ARM images with cypress/included – install Firefox
  log "jbt-cypress – Installing Firefox (if needed)"
  docker exec "jbt-cypress" bash -c "apt-get install -y --no-install-recommends firefox-esr && \
                                     apt-get clean && \
                                     rm -rf /var/lib/apt/lists/*"

  # With https://github.com/joomla/joomla-cms/pull/44253 Joomla command line client usage has been added
  # to the System Tests. Since Debian Bullseye’s official repositories only offer PHP 7.4 by default,
  # we install PHP 8.4 from Ondřej Surý repository in the Cypress container.
  #
  log "jbt-cypress – Adding PHP 8.4 to be able to execute cli/joomla.php from Joomla System Tests"
  # Add Ondřej Surý repository as PHP source
  docker exec "jbt-cypress" bash -c '
    set -e
    apt-get update && apt-get install -y --no-install-recommends apt-transport-https ca-certificates gnupg wget
    install -d /usr/share/keyrings
    wget -qO - https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${CODENAME:-trixie} main" > /etc/apt/sources.list.d/php.list
    apt-get update'
  # Install PHP 8.4; for ignoring apt-get update error, see Google Chrome GPG Key comment above
  docker exec "jbt-cypress" bash -c "apt-get update >/dev/null 2>&1; apt-get install -y php8.4 php8.4-simplexml php8.4-cli php8.4-common php8.4-curl php8.4-mbstring php8.4-xml php8.4-mysql php8.4-mysqli php8.4-pgsql"
  # Update the default PHP binary to PHP 8.4
  docker exec "jbt-cypress" bash -c "update-alternatives --set php /usr/bin/php8.4"

  log "Add bash for Alpine containers"
  for container in "jbt-pga" "jbt-mail"; do
    docker exec -u root ${container} apk add bash || true # Who cares?
  done

  log "Set container prompts for base containers"
  for container in "${JBT_BASE_CONTAINERS[@]}"; do
    docker exec -u root "${container}" sh -c \
      "echo PS1=\'${container} \# \' >> ~/.bashrc" || true # Who cares?
  done

  # pgpass file must me only pgadmin user read & writable
  log "Create pgAdmin password file with owner pgadmin and file mask 600"
  docker cp configs/pgpass jbt-pga:/pgadmin4/pgpass
  docker exec -u 0 jbt-pga bash -c "chmod 600 /pgadmin4/pgpass && chown pgadmin /pgadmin4/pgpass"

  log "*********************************************************************************************************************"
  log "Base installation is completed. If there should be an issue with any of the upcoming version-dependent installations,"
  log "the failed version-dependent installation could be repeated using 'recreate'."
  log "*********************************************************************************************************************"
fi

for version in "${versionsToInstall[@]}"; do
  instance=$(getMajorMinor "${version}")

  if [ "$recreate" = true ]; then

    # Container exists?
    if docker ps -a --format '{{.Names}}' | grep -q "^jbt-${instance}$"; then
      # Running?
      if docker ps --format '{{.Names}}' | grep -q "^jbt-${instance}$"; then
        log "jbt-${instance} – Stopping Docker Container"
        docker stop "jbt-${instance}"
      fi
      log "jbt-${instance} – Removing Docker container"
      docker rm -f "jbt-${instance}" || log "jbt-${instance} – Ignoring failure to remove Docker container"
    fi

    createDockerComposeFile "${instance}" "${php_version}" "${network}" "append"

    log "jbt-${instance} – Building Docker container"
    # Always attempt to pull a newer version of the image
    # Do not use cache when building the image
    docker compose build "jbt-${instance}" --pull --no-cache

    log "jbt-${instance} – Starting Docker container"
    docker compose up -d "jbt-${instance}"

  fi

  JBT_INTERNAL=42 bash scripts/setup.sh "initial" "${version}" "${database_variant}" "${socket}" \
                                        "${arg_repository}:${arg_branch}" "${patches[@]}"

  log "jbt-${instance} – Installing Joomla required Cypress binary version (if needed)"
  docker exec "jbt-cypress" bash -c "cd '/jbt/joomla-${instance}' && \
                                     CYPRESS_CACHE_FOLDER=/jbt/cypress-cache npx cypress install"

done
