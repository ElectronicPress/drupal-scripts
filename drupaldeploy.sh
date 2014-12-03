#!/bin/bash
#
# Must be root.
#
[ "$(id -u)" != "0" ] && { echo "Please run as root."; exit 1; }
#
# Must be one argument.
#
[ "$#" -ne 1 ] && { echo "Usage: drupaldeploy [drush-archive-dump-file]"; exit 1; }
#
# Archive exists.
#
ARCHIVE=$1 && [ ! -f "$ARCHIVE" ] &&
  { echo "The archive '$ARCHIVE' does not exist"; exit 1; }
#
# Valid archive.
#
tar -tzf "$ARCHIVE" &> /dev/null ||
  { echo "The archive '$ARCHIVE' is invalid"; exit 1; }
#
# App name
#
read -p 'Enter the app name: ' APP_NAME
#
# Database name.
#
read -p "Enter the database name [${APP_NAME}_v1]: " DB_NAME
DB_NAME="${DB_NAME:=${APP_NAME}_v1}"
#
# Database user.
#
read -p "Enter the database user name [$APP_NAME]: " DB_USER
DB_USER="${DB_USER:=$APP_NAME}"
#
# Database root password.
#
read -sp "Enter the database root password:" DB_ROOT
until [ "$DB_ROOT" != "" ] && mysql -u root -p"$DB_ROOT" -e ";" 2> /dev/null ; do
  read -sp "`echo $'\n'Could not connect, try again: `" DB_ROOT
done
#
# Approot
#
read -p "`echo $'\n'Enter the approot [/var/www/html/"$APP_NAME"]: `" APPROOT
APPROOT="${APPROOT:=/var/www/html/$APP_NAME}"
#
# git URL.
#
read -p "Enter the git repository url [git@github.com:ElectronicPress/${APP_NAME}.git]: " GIT_URL
GIT_URL="${GIT_URL:=git@github.com:ElectronicPress/${APP_NAME}.git}"
#
# Run ACL's.
#
[ -f "./drupalfacl.sh" ] &&
  read -p "Run drupalfacl.sh on $APPROOT? [Y/n]: " RUN_FACL &&
  RUN_FACL="${RUN_FACL:=y}";
#
# Check db exists.
#
DB_EXISTS=`mysql -uroot -p"$DB_ROOT" --skip-column-names -e "SHOW DATABASES LIKE '$DB_NAME'"` &&
  [ "$DB_EXISTS" == "$DB_NAME" ] &&
  read -p "Database $DB_NAME already exists, overwrite? [y/N]: " REMOVE_DB &&
  [[ ! "$REMOVE_DB"  =~ (y|Y) ]] &&
  { echo "Error: Database already exists."; exit 1; }
#
# Check approot exists.
#
[ -d "$APPROOT" ] &&
  read -p "Directory $APPROOT already exists, overwrite? [y/N]: " REMOVE_APPROOT &&
  [[ ! "$REMOVE_APPROOT" =~ (y|Y) ]] &&
  { echo "Error: directory already exists.";  exit 1; }
#
# Create the user, database, and grants.
#
printf "Creating database $DB_NAME..." &&
  mysql -uroot -p"$DB_ROOT" -e "GRANT ALL ON $DB_NAME.* to '$DB_USER'@'localhost' IDENTIFIED BY '${DB_USER}_localhost';" &&
  echo " done."
#
# Remove existing approot.
#
[ -d "$APPROOT" ] &&
  printf "Removing existing approot $APPROOT..." &&
  rm -rf "$APPROOT" &&
  echo " done."
#
# Create new approot, change to it.
#
printf "Creating approot $APPROOT..." &&
  mkdir -p "$APPROOT" &&
  cd "$APPROOT" &&
  echo " done."
#
# Import the site archive.
#
printf "Restoring $ARCHIVE to $APPROOT..." &&
  drush archive-restore "$ARCHIVE" --destination="$APPROOT"/docroot &> /dev/null &&
  echo " done."
#
# Initialize git.
#
printf "Configuring git..." &&
  git init > /dev/null &&
  git remote add origin "$GIT_URL" > /dev/null &&
  git pull origin master > /dev/null &&
  echo " done."
#
# Run ACL's
#
[[ "$RUN_FACL" =~ (y|Y) ]] &&
  printf "Setting ACLs..." &&
  cd - &&
  ./drupalfacl.sh "$APPROOT" > /dev/null &&
  echo " done."
#
# All good!
#
echo "Complete!"
exit 0
