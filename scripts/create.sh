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
socket=""
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
    socket="socket"
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
docker exec jbt_mysql mysql -uroot -proot -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';"
# And for MariaDB too
log "jbt_${version} – Enable MariaDB user root login with password."
docker exec jbt_madb mysql -uroot -proot -e  "ALTER USER 'root'@'%' IDENTIFIED BY 'root';"
# And Postgres (which have already user postgres with SUPERUSER, but to simplify we will use same user root on postgres)
log "jbt_${version} – Create PostgreSQL user root with password root and SUPERUSER role."
docker exec jbt_pg sh -c "\
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
  docker exec "jbt_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  JBT_INTERNAL=42 bash scripts/setup.sh "initial" "${version}" "${database_variant}" "${arg_repository}:${arg_branch}"

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
docker exec jbt_cypress sh -c "apt-get update && apt-get install -y git vim iputils-ping iproute2 telnet net-tools"

log "Add bash for Alpine containers"
for container in "jbt_pga" "jbt_mail"; do
  docker exec -u root ${container} apk add bash || true # Who cares?
done
log "Set container prompts for base containers"
for container in "${JBT_BASE_CONTAINERS[@]}"; do
  docker exec -u root "${container}" sh -c  \
    "echo PS1=\'${container} \# \' >> ~/.bashrc" || true # Who cares?
done
