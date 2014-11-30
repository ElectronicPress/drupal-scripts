#!/bin/bash

# Ensure archive argument.
if [ ! "$#" -eq 1 ]; then
  echo "Usage [archive]"
  exit 1
fi

# Set the archive.
ARCHIVE=$1

# Ensure archive exists.
if [ ! -f "$ARCHIVE" ]; then
  echo "The archive $5 does not exist"
  exit 1
fi

# Get the root database passwd
echo "Enter the sql root password"
read DB_ROOT

echo "Enter the new database name."
read DB_NAME

# Check if the database exists.
if [[ ! -z "`mysql -qfsBep -uroot -p "$DB_ROOT" "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'" 2>&1`" ]]; then

  # Warn user.
  echo "Database $DB_NAME already exists.  Do you want to remove it?  Enter y to to continue.";

  # Get ansser
  read REMOVE_DB

  # Check that it is to be removed.
  if [ ! "$REMOVE_DB" -eq "y" ]; then
    echo "Database already exists."
    exit 1
  fi

  # Remove the database.
  mysql -uroot -p "$DB_ROOT" -e "DROP DATABASE $DB_NAME"
fi

# Get the database user.
echo "Enter the new database user name"
read DB_USER

# Get the git url.
echo "Enter the git repository URL"
read GIT_URL

# Get the approot.
echo "Enter the new approot (NOT with docroot)"
read APPROOT

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

# Set facl script location.
FACL_SCRIPT=/var/www/scripts/drupalfacl.sh

# Check the script exists.
if [ -f "$FACL_SCRIPT" ]; then

  # Ask to run FACL.
  echo "Do you want to drupalfacl.sh w $APPROOT? Enter y to continue."
  read RUN_FACL

  # They want to run
  if [ "$RUN_FACL" -eq "y" ]; then
    eval "$FACL_SCRIPT w $APPROOT"
  fi;
fi

echo "Complete!"

exit 0;
