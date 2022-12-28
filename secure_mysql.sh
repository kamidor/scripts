#! /bin/bash
# This script is used to configure mariadb in a secure way

main(){
# Check if the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Check if mariadb is installed
if ! [ -x "$(command -v mysql)" ]; then
  echo 'Error: mariadb is not installed.' >&2
  exit 1
fi

# Check if parameter is passed
if [ -z "$1" ]
  then
    echo "No password supplied, generating random password"
    
    # Generate random password
    password=$(openssl rand -base64 22)
    echo 'Generated password: ' $password
    else
    password=$1
fi 

# Check if expect is installed
if ! [ -x "$(command -v expect)" ]; then
  echo 'Expect is not installed, installing now'
    DEBIAN_FRONTEND=noninteractive apt install -yq expect 
    purge=1
fi

# Run expect script
expect -c "
set timeout 10

spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\" 

expect \"Switch to unix_socket authentication\"
send \"n\r\"

expect \"Change the root password?\"
send \"y\r\"

expect \"New password:\"
send \"$password\r\"

expect \"Re-enter new password:\"
send \"$password\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
"
}

LOGGER=/root/scripts/logger.pl
LOGFILE=/root/ci.log

# Check if logger.pl exists and is executable
if ! [ -x "$LOGGER" ]; then
  echo 'Error: logger.pl is not installed.' >&2
  exit 1
fi

# Create log file if it doesn't exist
if ! [ -f "$LOGFILE" ]; then
  touch $LOGFILE
fi

main 2>&1 | $LOGGER >> $LOGFILE