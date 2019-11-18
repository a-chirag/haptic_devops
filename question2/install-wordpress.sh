#!/bin/bash
set -e

readonly DEFAULT_INSTALL_PATH="/"
readonly DEFAULT_VERSION="5.3"

readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-wordpress [OPTIONS]"
  echo
  echo "This script can be used to install wordpress and its dependencies."
  echo
  echo "Options:"
  echo
  echo -e "  --version\t\tThe version of wordpress to install. Required."
  echo -e "  --path\t\tThe path where wordpress should be installed. Ex - /myapps. Optional. Default: $DEFAULT_INSTALL_PATH."
  echo
  echo "Example:"
  echo
  echo "  install-wordpress --version 5.3"
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function install_dependencies {
  log_info "Installing dependencies"

  if $(has_apt_get); then
    sudo apt-get update -y
    sudo apt-get install -y nginx
    sudo apt-get install -y mysql-server
  elif $(has_yum); then
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
    sudo yum install epel-release
    sudo yum update -y
    sudo yum install -y nginx
    sudo yum install -y mysql-server
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
  sudo systemctl start mysqld
}

function configure_user_mysql {
  temp_password=$(grep password /var/log/mysqld.log | awk '{print $NF}')
  echo "ALTER USER 'root'@'localhost' IDENTIFIED BY 'myrootpass';" > reset_pass.sql
  echo "CREATE DATABASE wordpress;" >> reset_pass.sql
  echo "CREATE USER wordpressuser@localhost IDENTIFIED BY 'password';" >> reset_pass.sql
  echo "GRANT ALL PRIVILEGES ON wordpress.* TO wordpressuser@localhost;" >> reset_pass.sql
  echo "flush privileges;" >> reset_pass.sql
  mysql -u root --password="$temp_password" --connect-expired-password < reset_pass.sql
}

function install_binaries {
  local readonly version="$1"
  local readonly path="$2"

  local readonly url="https://wordpress.org/wordpress-${version}.tar.gz"
  local readonly download_path="/tmp/wordpress_${version}.tar.qz"
  local readonly wordpress_dest_path="/usr/local/nginx/$path"

  log_info "Downloading Wordpress $version from $url to $download_path"
  curl -o "$download_path" "$url"
  tar -xzvf $download_path
  cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
  echo "define('DB_NAME', 'wordpress');" >> /tmp/wordpress/wp-config.php
  echo "define('DB_USER', 'wordpressuser');" >> /tmp/wordpress/wp-config.php
  echo "define('DB_PASSWORD', 'password');" >> /tmp/wordpress/wp-config.php
  log_info "Moving wordpress to $wordpress_dest_path"
  sudo mv "/tmp/wordpress/*" "$wordpress_dest_path"
}

function install {
  local version=$DEFAULT_VERSION
  local path="$DEFAULT_INSTALL_PATH"

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --version)
        version="$2"
        shift
        ;;
      --path)
        path="$2"
        shift
        ;;
      --user)
        user="$2"
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--version" "$version"
  assert_not_empty "--path" "$path"

  log_info "Starting wordpress install"

  install_dependencies
  install_binaries "$version" "$path" "$user"
  configure_user_mysql
  log_info "Wordpress install complete!"
  log_info "server=127.0.0.1;uid=wordpressuser;pwd=password;database=wordpress"
}

install "$@"
