#!/bin/bash

# Ensure 5 arguments.
if [ ! "$#" -eq 5 ]; then
  echo "Usage [db-user] [db-name] [git-url] [approot] [archive]"
  exit 1
fi

# Ensure archive exists.
if [ ! -f "$5" ]; then
  echo "The archive $5 does not exist"
  exit 1
fi

# Set vars
DB_USER=$1
DB_NAME=$2
GIT_URL=$3
APPROOT=$4
ARCHIVE=$5

# Create the user, database, and grants.
mysql -uroot -p -e \
  "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '${DB_USER}_localhost'; \
   CREATE DATABASE $DB_NAME; \
   GRANT ALL ON $DB_NAME.* to '$DB_USER'@'localhost';"

# Create and change to approot.
mkdir -p "$APPROOT" && cd "$APPROOT"

# Import the site archive.
drush archive-restore "$ARCHIVE" --destination="$ARCHIVE"/docroot

# Initialize git.
git init
git remote add origin "$GIT_URL"
git pull origin master

# Run facl.
/var/www/scripts/drupalfacl.sh w "$APPROOT"
