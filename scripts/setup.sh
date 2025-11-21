#!/bin/bash -e
#
# setup.sh - Install and configure Docker web server containers initial or after switching PHP version.
#   setup.sh 53
#   setup.sh 53 initial pgsql socket https://github.com/Elfangor93/joomla-cms:mod_community_info
#
# Distributed under the GNU General Public License version 2 or later, Copyright (c) 2024-2025 Heiko Lübbe
# https://github.com/muhme/joomla-branches-tester

if [[ $(dirname "$0") != "scripts" || ! -f "scripts/helper.sh" ]]; then
  echo "Please run me as 'scripts/setup'. Thank you for your cooperation! :)"
  exit 1
fi

source scripts/helper.sh

function help {
  echo "
    setup.sh – Sets up the web server Docker container internally, used by 'scripts/create' and 'scripts/php'.
               Please specify a Joomla version. Choose one of the available versions listed in 'scripts/version'.
               Optional 'initial' argument for first-time installation.
               Optional initial database variant: ${JBT_DB_VARIANTS[*]} (default is mariadbi).
               Optional initial 'repository:branch', e.g. https://github.com/Elfangor93/joomla-cms:mod_community_info.
               Optional initial 'socket' enables database access via Unix socket (default is TCP host).
               Optional 'unpatched' or one or multiple patches (default: ${JBT_DEFAULT_PATCHES[*]}).
               The optional argument 'help' displays this page. For full details see https://bit.ly/JBT-README.
    $(random_quote)"
}

# Defaults to use MariaDB with MySQLi database driver, to use cache and highest PHP version
database_variant="mariadbi"
initial=false
socket=false
unpatched=false
patches=()

while [ $# -ge 1 ]; do
  if [[ "$1" =~ ^(help|-h|--h|-help|--help|-\?)$ ]]; then
    help
    exit 0
  elif isValidVersion "$1"; then
    version="$1"
    shift # Argument is eaten as one version number.
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
  elif [ "$1" = "unpatched" ]; then
    unpatched=true
    shift # Argument is eaten as unpatched option.
  elif [[ "$1" =~ ^(joomla-cms|joomla-cypress|database)-[0-9]+$ ]]; then
    patches+=("$1")
    shift # Argument is eaten as a patch.
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
  error "Please specify a Joomla version. Choose one of the available versions listed in 'scripts/version'."
  exit 1
fi

if [ "$unpatched" = true ]; then
  patches=("unpatched")
elif [ ${#patches[@]} -eq 0 ]; then
  patches=("${JBT_DEFAULT_PATCHES[@]}")
fi
# else: patches are filled in array

instance=$(getMajorMinor "${version}")

log "jbt-${instance} – Create 'php/conf.d/error-logging.ini' to catch all PHP errors, notices and deprecated warnings"
sed -e "s/JBT_INSTANCE/${instance}/" 'configs/error-logging.ini' > "${JBT_TMP_FILE}"
docker cp "${JBT_TMP_FILE}" "jbt-${instance}:/usr/local/etc/php/conf.d/error-logging.ini"
# e.g. "jbt-54 – Using PHP error_log = joomla-54/administrator/logs/php.log"
log "jbt-${instance} – Using PHP $(grep error_log < "${JBT_TMP_FILE}" | sed 's|/jbt/||')"

log "jbt-${instance} – Create 'php/conf.d/jbt.ini' to prevent Joomla warnings"
docker cp 'configs/jbt.ini' "jbt-${instance}:/usr/local/etc/php/conf.d/jbt.ini"

log "jbt-${instance} – Import jbt-proxy certificate"
docker exec "jbt-${instance}" bash -c ' \
  cp /mitm/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy.crt; \
  update-ca-certificates'

log "jbt-${instance} – Configure PHP to use jbt-proxy"
  docker exec "jbt-${instance}" bash -c ' \
        echo "# Proxy for outbound HTTP(S)"             >> /etc/apache2/envvars; \
        echo "export http_proxy=http://jbt-proxy:7008"  >> /etc/apache2/envvars; \
        echo "export https_proxy=http://jbt-proxy:7008" >> /etc/apache2/envvars; \
        echo "export no_proxy=localhost,127.0.0.1,::1"  >> /etc/apache2/envvars'

# No 'docker-php-ext-install opache' as with PHP 8.5 it is built in and fails because there’s no module to compile.
# Alternativly, we could make a difference for <= 8.5, but opcache is only for performance and not a required module.
#
# zip and zstd only to be able to run build
#
log "jbt-${instance} – Installing packages"
docker exec "jbt-${instance}" bash -c 'apt-get update && apt-get install -y \
  libpng-dev \
  libjpeg-dev \
  libfreetype6-dev \
  libwebp-dev \
  libldap2-dev \
  libzip-dev \
  unzip \
  libonig-dev \
  libxml2-dev \
  libicu-dev \
  libxslt1-dev \
  git \
  zlib1g-dev \
  libpq-dev \
  libbz2-dev \
  postgresql-client \
  default-mysql-client \
  zip \
  zstd \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install -j$(nproc) \
      gd \
      ldap \
      zip \
      pdo \
      pdo_mysql \
      mysqli \
      pdo_pgsql \
      intl \
      xsl \
      bz2 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*'

# gh only to use it for applying GitHub PRs manually
log "jbt-${instance} – Installing gh command"
docker exec "jbt-${instance}" bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl gnupg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
  apt-get update
  apt-get install -y --no-install-recommends gh
  rm -rf /var/lib/apt/lists/*'

failed=false
if [[ "${JBT_GITHUB_TOKEN}" =~ ghp_* ]]; then
  log "jbt-${instance} – Take over environment found JBT_GITHUB_TOKEN as GH_TOKEN into container"
  docker exec "jbt-${instance}" bash -c "echo \"export GH_TOKEN=$JBT_GITHUB_TOKEN\" >> ~/.bashrc" || failed=true
elif [[ "${GH_TOKEN}" =~ ghp_* ]]; then
  log "jbt-${instance} – Take over environment found GH_TOKEN into container"
  docker exec "jbt-${instance}" bash -c "echo \"export GH_TOKEN=${GH_TOKEN}\" >> ~/.bashrc" || failed=true
elif [[ "${GITHUB_TOKEN}" =~ ghp_* ]]; then
  log "jbt-${instance} – Take over environment found GITHUB_TOKEN into container"
  docker exec "jbt-${instance}" bash -c "echo \"export GH_TOKEN=${GITHUB_TOKEN}\" >> ~/.bashrc" || failed=true
else
  warning "jbt-${instance} – GH_TOKEN could not be configured because no environment variable is set (ignored)"
fi
if $failed; then
  warning "jbt-${instance} – Failed configuration of GH_TOKEN (ignored)"
fi

log "jbt-${instance} – Configure Joomla installation to disable localhost check, enable mod_rewrite and SSL"
docker exec "jbt-${instance}" bash -c '
  echo "SetEnv JOOMLA_INSTALLATION_DISABLE_LOCALHOST_CHECK 1" > /etc/apache2/conf-available/joomla-env.conf && \
  a2enconf joomla-env && \
  a2enmod rewrite ssl'

log "jbt-${instance} – Importing JBT CA certificate and configuring Apache"
docker exec "jbt-${instance}" bash -c "
  cp /jbt/certs/jbt-ca.crt /usr/local/share/ca-certificates && \
  update-ca-certificates &&
  cp /jbt/configs/001-ssl.conf /etc/apache2/sites-available && \
  cd /etc/apache2/sites-enabled && \
  ln -s ../sites-available/001-ssl.conf 001-ssl.conf"

# Needs PHP >= 8.0, therefore not possible for Joomla 3.9 with PHP 7.4, but possible for 3.10 with PHP 8.0
with_xdebug=false
php_version=$(docker exec "jbt-${instance}" php -r 'echo PHP_VERSION;')
log "jbt-${instance} – Used PHP version is ${php_version}"
if [ "$(printf '%s\n' "8.0.0" "$php_version" | sort -V | head -n1)" = "8.0.0" ]; then
  # Create two PHP environments: one with Xdebug and one without.
  # Manage them by cloning /usr/local, and use symbolic links to toggle between the two installations.
  with_xdebug=true
  log "jbt-${instance} – Configure 'php.ini' for development"
  docker exec "jbt-${instance}" bash -c "cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini"
  log "jbt-${instance} – Preparing a parallel installation with Xdebug"
  docker exec "jbt-${instance}" bash -c 'cp -r /usr/local /usr/local-without-xdebug'
  # TODO: 21 Nov 2025 to be deleted once pecl/xdebug supports PHP 8.5
  if [[ $php_version == 8.5.* ]]; then
    # 'pecl install xdebug' requires PHP (version >= 8.0.0, version <= 8.4.99), we have to compile by own
    docker exec "jbt-${instance}" bash -c '
      set -eux
      apt-get update
      apt-get install -y --no-install-recommends git $PHPIZE_DEPS
      git clone --depth=1 https://github.com/xdebug/xdebug.git /usr/src/xdebug
      cd /usr/src/xdebug
      phpize
      ./configure --enable-xdebug
      make -j"$(nproc)"
      make install'
  else
    docker exec "jbt-${instance}" bash -c 'pecl install xdebug'
  fi
  docker exec "jbt-${instance}" bash -c 'docker-php-ext-enable xdebug'
  xdebug_path=$(docker exec "jbt-${instance}" bash -c 'find /usr/local/lib/php/extensions/ -name "xdebug.so" | head -n 1')
  # As port number for 3.10 use 7910
  docker exec "jbt-${instance}" bash -c "
  cat <<EOF > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
  zend_extension=${xdebug_path}
  xdebug.mode=debug
  xdebug.start_with_request=yes
  xdebug.client_host=host.docker.internal
  xdebug.client_port=79${instance: -2}
  xdebug.log=/var/www/html/administrator/logs/xdebug.log
  xdebug.discover_client_host=true
  EOF
  "
  docker exec "jbt-${instance}" bash -c ' \
      mv /usr/local /usr/local-with-xdebug && \
      ln -s /usr/local-without-xdebug /usr/local'
  # Apache is not restarted because /var/www/html is then in use, and would cause the following git clone to fail.
else
  log "jbt-${instance} – No parallel installation with Xdebug" 
fi

# Installing Node.js v22 and cron for Joomla Task Scheduler
# Additional having vim, ping, telnet, netstat for comfort
log "jbt-${instance} – Installing additional Linux packages"
docker exec "jbt-${instance}" bash -c 'apt-get update -qq && \
    apt-get upgrade -y && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y cron git unzip vim nodejs iputils-ping iproute2 telnet net-tools'

if $initial; then
  if [ -z "${arg_repository}" ]; then
    git_repository="https://github.com/joomla/joomla-cms"
    git_branch=$(fullName "${version}")
  else
    git_repository="$arg_repository"
    git_branch="${arg_branch}"
  fi
  # Starting here with a shallow clone for speed and space; unshallow in 'scripts/patch' if patches are to be applied
  log "jbt-${instance} – Git shallow cloning ${git_repository}:${git_branch} into the 'joomla-${instance}' directory"
  docker exec "jbt-${instance}" bash -c "\
    rm -rf /var/www/html/* /var/www/html/.??*; \
    git clone -b ${git_branch} --depth 1 ${git_repository} /var/www/html"

  if ((instance != 310 && instance >= 50)); then
    version_file="joomla-${instance}/libraries/src/Version.php"
    if grep -q "DEV_STATUS = 'Stable'" "${version_file}"; then
      log "jbt-${instance} – Change DEV_STATUS from 'Stable' to 'JBT' to login even with installation folder"
      sed -e "s/DEV_STATUS = 'Stable'/DEV_STATUS = 'JBT'/" "${version_file}" > "${JBT_TMP_FILE}" && \
        cp "${JBT_TMP_FILE}" "${version_file}"
    fi
  fi
fi

log "jbt-${instance} – Git configure '/var/www/html' as safe directory"
docker exec "jbt-${instance}" bash -c "git config --global --add safe.directory \"/var/www/html\""

# Running composer install even if we are not initial - just in case.
if [ -f "joomla-${instance}/composer.json" ]; then
  log "jbt-${instance} – Running composer install"
  docker exec "jbt-${instance}" bash -c "cd /var/www/html && \
    php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && \
    php composer-setup.php && \
    rm composer-setup.php && \
    mv composer.phar /usr/local/bin/composer"
    if $with_xdebug; then
      docker exec "jbt-${instance}" bash -c "cd /var/www/html && \
        cp -p /usr/local/bin/composer /usr/local-with-xdebug/bin/composer"
    fi
  docker exec "jbt-${instance}" bash -c "cd /var/www/html && composer install" ||
    (log 'composer install failed on the first attempt; give it a second try' &&
      docker exec "jbt-${instance}" bash -c "cd /var/www/html && composer install")
  # There is a race condition (perhaps with the parallel downloads), some times composer install fails:
  # "Failed to open directory: No such file or directory"
  # As the second run was always successful, we try it directly.
fi

if $initial; then
  # npm clean install only initial, with switching PHP version nothing changed for JavaScript
  if [ -f "joomla-${instance}/package.json" ]; then
    log "jbt-${instance} – Running npm clean install"
    docker exec "jbt-${instance}" bash -c 'cd /var/www/html && npm ci'
  fi

  if [ "$unpatched" = true ]; then
    log "jbt-${instance} – Installation remains unpatched"
  else
    log "jbt-${instance} – Patching the installation with ${patches[*]}"
    scripts/patch.sh "${instance}" "${patches[@]}"
  fi
fi

# Needed on Windows WSL2 Ubuntu to be able to run Joomla Web Installer
log "jbt-${instance} – Changing ownership to 'www-data' for all files and directories"
# Following error seen on macOS, we ignore it as it does not matter, these files are 444
# chmod: changing permissions of
#   '/var/www/html/.git/objects/pack/pack-b99d801ccf158bb80276c7a9cf3c15217dfaeb14.pack': Permission denied
docker exec "jbt-${instance}" bash -c 'chown -R www-data:www-data /var/www/html >/dev/null 2>&1 || true'

if [[ -d "joomla-${instance}/installation" && ! -d "installation/joomla-${instance}/installation" ]]; then
  # Save the Joomla 'installation' directory to preserve it for the next Joomla installation,
  # e.g. switching the database after grafting.
  log "jbt-${instance} – Creating a backup of the Joomla 'installation' directory into 'installation/joomla-${instance}'"
  docker exec "jbt-${instance}" bash -c "\
    mkdir -p '/jbt/installation/joomla-${instance}' && \
    cp -r installation /jbt/installation/joomla-${instance}"
fi

# Joomla container needs to be restarted
log "jbt-${instance} – Restarting container"
docker restart "jbt-${instance}"

# Configure and install Joomla with desired database variant
if $initial; then
  if [ "${socket}" = true ]; then
    scripts/database.sh "${instance}" "${database_variant}" "socket"
  else
    scripts/database.sh "${instance}" "${database_variant}"
  fi
fi

# Define the cron job entry
cronjob="* * * * * /usr/local/bin/php /var/www/html/cli/joomla.php scheduler:run --all --no-interaction --quiet || true"
# Check if the cron job already exists
if ! docker exec "jbt-${instance}" bash -c "(crontab -l 2>/dev/null || echo '') | grep -F \"$cronjob\" > /dev/null"; then
  log "jbt-${instance} – Adding cron job for Joomla Task Scheduler"
  docker exec "jbt-${instance}" bash -c "
    ( ( crontab -l 2>/dev/null || echo "" );
    echo '# Joomla Task Scheduler, ignore exit status e.g. 127 No tasks due!';
    echo \"$cronjob\" ) | crontab -"
fi

log "jbt-${instance} – Set container prompt"
docker exec "jbt-${instance}" bash -c "echo PS1=\'jbt-${instance} \# \' >> ~/.bashrc" || true # Who cares?
