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
read -s -p "Enter the sql root password:" DB_ROOT

# Check correct creds.
until mysql -u root -p"$DB_ROOT"  -e ";" ; do
  read -s -p "Can't connect, please retry:" DB_ROOT
done

# Get the database name.
read -p $'\nEnter the new database name:' DB_NAME

# Check if DB exists.
if [ "`mysql -uroot -p"$DB_ROOT" --skip-column-names -e "SHOW DATABASES LIKE '$DB_NAME'"`" == "$DB_NAME" ]; then

  # Warn user.
  read -p "Database $DB_NAME already exists.  Enter y to overwrite: " REMOVE_DB

  # Check that it is to be removed.
  if [ "$REMOVE_DB" != "y" ]; then
    echo "Error: Database already exists."
    exit 1
  fi
fi

# Get the database user.
read -p $'\nEnter the new database user name: ' DB_USER

# Get the git url.
read -p $'\nEnter the git repository URL: ' GIT_URL

# Get the approot.
read -p $'\nEnter the new approot (NOT with docroot): ' APPROOT

# Create the user, database, and grants.
mysql -uroot -p"$DB_ROOT" -e \
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
  read -p $'\nEnter y to run drupalfacl.sh w on $APPROOT: ' RUN_FACL

  # They want to run
  if [ "$RUN_FACL" == "y" ]; then
    eval "$FACL_SCRIPT w $APPROOT"
  fi;
fi

echo "Complete!"

exit 0;
