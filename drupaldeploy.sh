#!/bin/bash

#
# Validate stuff.
#

# Ensure archive argument.
if [ ! "$#" -eq 1 ]; then
  echo "Usage [archive]"
  exit 1
fi

# Set the archive.
ARCHIVE=$1

# Ensure archive exists.
if [ ! -f "$ARCHIVE" ]; then
  echo "The archive $ARCHIVE does not exist"
  exit 1
fi

#
# Get stuff.
#

# Get app name.
read -p 'Enter the app name: ' APP_NAME

# Get the database name.
DB_NAME_DEFAULT="${APP_NAME}_v1"
read -p "Enter the database name [$DB_NAME_DEFAULT]: " DB_NAME
if [ "$DB_NAME" == "" ]; then
  DB_NAME="$DB_NAME_DEFAULT"
fi;

# Get the database user.
DB_USER_DEFAULT="$APP_NAME"
read -p "Enter the database user name [$DB_USER_DEFAULT]: " DB_USER
if [ "$DB_USER" == "" ]; then
  DB_USER="$DB_USER_DEFAULT"
fi;

# Get the root database password.
read -s -p "Enter the database root password: " DB_ROOT
# Check correct creds.
until mysql -u root -p"$DB_ROOT"  -e ";" ; do
  read -s -p "Can't connect, please retry: " DB_ROOT
done

# Get the approot.
APPROOT_DEFAULT="/var/www/html/$APP_NAME"
echo ""
read -p "Enter the new approot [$APPROOT_DEFAULT]: " APPROOT
if [ "$APPROOT" == "" ]; then
  APPROOT="$APPROOT_DEFAULT"
fi;

# Get the git url.
GIT_URL_DEFAULT="git@github.com:ElectronicPress/${APP_NAME}.git"
read -p "Enter the git SSH Clone URL: [$GIT_URL_DEFAULT]: " GIT_URL
if [ "$GIT_URL" == "" ]; then
  GIT_URL="$GIT_URL_DEFAULT"
fi;

# Get run facl.
FACL_SCRIPT=/var/www/scripts/drupalfacl.sh
if [ -f "$FACL_SCRIPT" ]; then
  read -p "Run drupalfacl.sh w on $APPROOT [y]: " RUN_FACL

  if [ "$RUN_FACL" == "" ]; then
    RUN_FACL="y"
  fi
fi

#
# Check stuff.
#

# Check db exists
DB_EXISTS=`mysql -uroot -p"$DB_ROOT" --skip-column-names -e "SHOW DATABASES LIKE '$DB_NAME'"`
if [ "$DB_EXISTS" == "$DB_NAME" ]; then

  # Warn user.
  read -p "Database $DB_NAME already exists, enter y to overwrite: " REMOVE_DB

  # Check that it is to be removed.
  if [ "$REMOVE_DB" != "y" ]; then
    echo "Error: Database already exists."
    exit 1
  fi
fi

# Check approot exists.
if [ -d "$APPROOT" ]; then

  # Warn user.
  read -p "Directory $APPROOT already exists.  Enter y to overwrite: " REMOVE_APPROOT

  # Check that it is to be removed.
  if [ "$REMOVE_APPROOT" != "y" ]; then
    echo "Error: directory already exists."
    exit 1
  fi

  # Remove the approot directory.
  rm -rf "$APPROOT"
fi

#
# Do stuff
#

# Create the user, database, and grants.
printf "Creating database $DB_NAME..."
mysql -uroot -p"$DB_ROOT" -e "GRANT ALL ON $DB_NAME.* to '$DB_USER'@'localhost' IDENTIFIED BY '${DB_USER}_localhost';"
echo " done."

# Create and change to approot.
printf "Creating approot $APPROOT..."
mkdir -p "$APPROOT" && cd "$APPROOT"
echo " done."

# Import the site archive.
printf "Restoring $ARCHIVE to $APPROOT..."
drush archive-restore "$ARCHIVE" --destination="$APPROOT"/docroot &> /dev/null
echo " done."

# Initialize git.
printf "Configuring git..."
git init &> /dev/null
git remote add origin "$GIT_URL" &> /dev/null
git pull origin master &> /dev/null
echo " done."

# Run ACL's
if [ "$RUN_FACL" == "y" ]; then
  printf "Setting ACLs..."
  eval "$FACL_SCRIPT w $APPROOT" &> /dev/null
  echo " done."
fi;

# All good!
echo "Complete!"
exit 0;
