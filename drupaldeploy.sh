#!/bin/bash

# Ensure 5 arguments.
if [ ! "$#" -eq 5 ]; then
  echo "Usage [db-user] [db-name] [git-url] [approot] [archive]"
  exit 1
fi

# Set arguments to vars
DB_USER=$1
DB_NAME=$2
GIT_URL=$3
APPROOT=$4
ARCHIVE=$5

# Ensure archive exists.
if [ ! -f "$ARCHIVE" ]; then
  echo "The archive $5 does not exist"
  exit 1
fi

# Warn if DB already exists
if [[ ! -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}2'" 2>&1`" ]];
then
  echo "DATABASE ALREADY EXISTS"
else
  echo "DATABASE DOES NOT EXIST"
fi

exit 1;
# Create the user, database, and grants.
mysql -uroot -p -e \
  "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '${DB_USER}_localhost'; \
   CREATE DATABASE $DB_NAME; \
   GRANT ALL ON $DB_NAME.* to '$DB_USER'@'localhost';"

# Create and change to approot.
mkdir -p "$APPROOT" && cd "$APPROOT"

# Import the site archive.
drush archive-restore "$ARCHIVE" --destination="$APPROOT"/docroot

# Initialize git.
git init
git remote add origin "$GIT_URL"
git pull origin master

# Run facl.
/var/www/scripts/drupalfacl.sh w "$APPROOT"
