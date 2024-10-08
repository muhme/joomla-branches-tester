#!/bin/bash -e
#
# create.sh - Create Docker containers based on Joomla Git branches.
#   create
#   create 51 pgsql socket no-cache
#   create 52 53 php8.1 recreate
#   create 52 https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/create'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    create – Create base Docker containers and containers based on Joomla Git branches.
             Optional Joomla version can be one or more of the following: ${allVersions[@]} (default is all).
             Optional database variant can be one of: ${JBT_DB_VARIANTS[@]} (default is mariadbi).
             Optional 'socket' for using the database with a Unix socket (default is using TCP host).
             Optional 'IPv6' can be set (default is to use IPv4).
             Optional 'no-cache' can be set (default is to use cache).
             Optional 'recreate' to create or recreate only one or more web server containers.
             Optional PHP version can be one of: ${JBT_PHP_VERSIONS[@]} (default is php8.1).
             Optional 'repository:branch', e.g. https://github.com/Elfangor93/joomla-cms:mod_community_info.
             Optional 'unpatched' or one or multiple patches (default: ${JBT_DEFAULT_PATCHES[@]})

             $(random_quote)
    "
}

versions=$(getVersions)
IFS=' ' allVersions=($(sort <<<"${versions}"))
unset IFS # map to array

# Defaults to use MariaDB with MySQLi database driver, to use cache and PHP 8.1.
database_variant="mariadbi"
socket=""
network="IPv4"
no_cache=false
recreate=false
php_version="php8.1"
versionsToInstall=()
unpatched=false
patches=()
while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1" "$versions"; then
    versionsToInstall+=("$1")
    shift # Argument is eaten as one version number.
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
  elif [ "$1" = "no-cache" ]; then
    no_cache=true
    shift # Argument is eaten as no cache option.
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

if [ ! -z "${git_repository}" ] && [ ${#versionsToInstall[@]} -ne 1 ]; then
  error "If you use repository:branch, please specify one version as one of the following: ${allVersions[@]}."
  exit 1
fi

if [ "$recreate" = true ] && [ ! -f docker-compose.yml ]; then
  error "The 'recreate' option was given, but no 'docker-compose.yml' file exists. Please run 'scripts/create' first."
  exit 1
fi

# If no version was given, use all.
if [ ${#versionsToInstall[@]} -eq 0 ]; then
  versionsToInstall=(${allVersions[@]})
fi

if [ "$unpatched" = true ]; then
  patches=("unpatched")
elif [ ${#patches[@]} -eq 0 ]; then
  patches=(${JBT_DEFAULT_PATCHES[@]})
fi
# else: patches are already filled in the array

if [ "$recreate" = false ]; then

  # Delete all docker containers and branches_* directories.
  scripts/clean.sh

  # Create Docker Compose setup with Joomla web servers for all versions to be installed.
  log "Create 'docker-compose.yml' file for version(s) ${versionsToInstall[*]}, based on ${php_version} and ${network}"
  createDockerComposeFile "${versionsToInstall[*]}" "${php_version}" "${network}"

  if $no_cache; then
    log "Running 'docker compose build --no-cache'"
    docker compose build --no-cache
  fi

  log "Running 'docker compose up'"
  docker compose up -d
fi

# Wait until MySQL database is up and running
# (This isn't accurate when using MariaDB or PostgreSQL, but so far it's working with the delay from MySQL.)
MAX_ATTEMPTS=60
attempt=1
until docker exec jbt_mysql mysqladmin ping -h"127.0.0.1" --silent || [ $attempt -eq $MAX_ATTEMPTS ]; do
  log "Waiting for MySQL to be ready, attempt $attempt of $MAX_ATTEMPTS"
  attempt=$((attempt + 1))
  sleep 1
done
# If the MAX_ATTEMPTS are exceeded, simply try to continue.

if [ "$recreate" = false ]; then

  # For the tests we need old-school user/password login, once over TCP and once for localhost with Unix sockets
  log "jbt_${version} – Enable MySQL user root login with password"
  docker exec jbt_mysql mysql -uroot -proot \
    -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root';" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root';"
  # And for MariaDB too
  log "jbt_${version} – Enable MariaDB user root login with password"
  docker exec jbt_madb mysql -uroot -proot \
    -e "ALTER USER 'root'@'%' IDENTIFIED BY 'root';" \
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"
  # And Postgres (which have already user postgres with SUPERUSER, but to simplify we will use same user root on postgres)
  log "jbt_${version} – Create PostgreSQL user root with password root and SUPERUSER role"
  docker exec jbt_pg sh -c "\
  psql -U postgres -c \"CREATE USER root WITH PASSWORD 'root';\" && \
  psql -U postgres -c \"ALTER USER root WITH SUPERUSER;\""
fi

for version in "${versionsToInstall[@]}"; do

  if [ "$recreate" = true ]; then

    # Container exists?
    if docker ps -a --format '{{.Names}}' | grep -q "^jbt_${version}$"; then
      # Running?
      if docker ps --format '{{.Names}}' | grep -q "^jbt_${version}$"; then
        log "jbt_${version} – Stopping Docker Container"
        docker compose stop "jbt_${version}"
      fi
      log "jbt_${version} – Removing Docker container"
      docker compose rm -f "jbt_${version}" || log "jbt_${version} – Ignoring failure to remove Docker container"
    fi

    createDockerComposeFile "${version}" "${php_version}" "${network}" "append"

    log "jbt_${version} – Building Docker container"
    docker compose build "jbt_${version}"

    log "jbt_${version} – Starting Docker container"
    docker compose up -d "jbt_${version}"

  fi

  # If the copying has not yet been completed, then we have to wait, or we will get e.g.
  # rm: cannot remove '/var/www/html/libraries/vendor': Directory not empty.
  max_retries=120
  for ((i = 1; i < $max_retries; i++)); do
    docker logs "jbt_${version}" 2>&1 | grep 'This server is now configured to run Joomla!' && break || {
      log "Waiting for original Joomla installation, attempt ${i} of ${max_retries}"
      sleep 1
    }
  done
  if [ $i -ge $max_retries ]; then
    error "Failed after $max_retries attempts. Giving up."
    exit 1
  fi
  log "jbt_${version} – Deleting original Joomla installation"
  docker exec "jbt_${version}" bash -c 'rm -rf /var/www/html/* && rm -rf /var/www/html/.??*'

  JBT_INTERNAL=42 bash scripts/setup.sh "initial" "${version}" "${database_variant}" "${socket}" \
                                        "${arg_repository}:${arg_branch}" ${patches[@]}

done

# Final actions if performing a base installation.
if [ "$recreate" = false ]; then
  log "Creating File '.vscode/launch.json' for all versions ${allVersions[*]}"
  launch_json=".vscode/launch.json"
  dir=$(dirname "${launch_json}")
  mkdir -p "${dir}" 2>/dev/null || (sudo mkdir -p "${dir}" && sudo 777 "${dir}")
  cat >"${launch_json}" <<EOF
{
    "version": "0.2.0",
    "configurations": [
EOF
  for version in "${allVersions[@]}"; do
    cat >>"${launch_json}" <<EOF
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
  cat >>"${launch_json}" <<EOF
    ]
}
EOF

  log "Installing vim, ping, ip, telnet and netstat in the 'jbt_cypress' container"
  docker exec jbt_cypress sh -c "apt-get update && apt-get install -y git vim iputils-ping iproute2 telnet net-tools"

  log "Add bash for Alpine containers"
  for container in "jbt_pga" "jbt_mail"; do
    docker exec -u root ${container} apk add bash || true # Who cares?
  done

  log "Set container prompts for base containers"
  for container in "${JBT_BASE_CONTAINERS[@]}"; do
    docker exec -u root "${container}" sh -c \
      "echo PS1=\'${container} \# \' >> ~/.bashrc" || true # Who cares?
  done

  # pgpass file must me only pgadmin user read & writable
  log "Create pgAdmin password file with owner pgadmin and file mask 600"
  docker cp scripts/pgpass jbt_pga:/pgadmin4/pgpass
  docker exec -u 0 jbt_pga bash -c "chmod 600 /pgadmin4/pgpass && chown pgadmin /pgadmin4/pgpass"
fi
