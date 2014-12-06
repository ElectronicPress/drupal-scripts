#!/bin/bash
#===============================================================================
#
#                             Drupal Deploy-Migrate
#
#        FILE: ddm.sh
#
#       USAGE: ddm.sh [(m)igrate|(p)ermissions|(h)ttpd VirtualHost|(i)ptables]
#
# DESCRIPTION: Migration and deployment assistasnt focused on Drupal.
#
#===============================================================================

#===  VARIABLES  ===============================================================

# If the shared variables have alrady been set.
SHARED_VARS_COMPUTED=""

# The shared variables.
APP_NAME=""
APP_ROOT=""

# SELinux Context default.
CHCON_CONTEXT_DEFAULT="system_u:object_r:httpd_sys_content_t:s0"

# ACL defaults for httpd and general.
FACL_HTTPD_DEFAULT="g:web-drupal:rwX,d:g:web-drupal:rwX"
FACL_DEFAULT="u::rwX,g::---,o::---,g:web-user:r-X,g:web-admin:rwX,m::rwx,\
             d:u::rwX,d:g::---,d:o::---,d:g:web-user:r-X,d:g:web-admin:rwX,\
             d:m::rwx"
FACL_DEFAULT=`echo ${FACL_DEFAULT}`

#===============================================================================

#===============================================================================
#
#                         Minor & Helper Functions
#
#===============================================================================

#===  FUNCTION  ================================================================
#         NAME: dsm_get_shared_vars
#  DESCRIPTION: Prompt and save the APP_NAME and APP_ROOT variables.
#===============================================================================
ddm_get_shared_vars()
{
  # Only need to set once.
  [ ! -z "$SHARED_VARS_COMPUTED" ] && return 0 || SHARED_VARS_COMPUTED=1

  # Get app name.
  until [ ! -z "$APP_NAME" ]; do read -p "Enter the app name: " APP_NAME; done

  # Get app root.
  read -p "`echo $'\n'`Enter the app root [/var/www/html/$APP_NAME]: " APP_ROOT

  # Set to default if not given.
  APP_ROOT="${APP_ROOT:=/var/www/html/$APP_NAME}"
}

#===  FUNCTION  ================================================================
#         NAME: ddm_chcon
#  DESCRIPTION: Set file contexts for SELinux.
# PARAMATER $1: The path of the file or directory.
#===============================================================================
ddm_chcon ()
{
  # Bail if no path set.
  [[ ! -f "$1" && ! -d "$1" ]] &&
  echo "No path set. Skipping contexts." &&
  return 0;

  # Set the context.
  printf "Setting contexts... "
  chcon -R "$CHCON_CONTEXT_DEFAULT" "$1"
  echo " done."
}

#===  FUNCTION  ================================================================
#         NAME: ddm_facl
#  DESCRIPTION: Set file ACL's.
# PARAMATER $1: The path of the file or directory.
#===============================================================================
ddm_facl ()
{
  # Bail if no path set.
  [[ ! -f "$1" && ! -d "$1" ]] &&
  echo "No path set. Skipping File ACLs." &&
  return 0;

  # Set default ACLs.
  printf "Setting default ACLs ..."
  setfacl -Rbm "$FACL_DEFAULT" "$1"
  echo " done."

  # Set *sites/default/files* default ACLs so httpd can write.
  [ -d "$1" ] &&
  printf "Setting files directory ACLs... "
  find "$1" -path "*sites/default/files" -print0 | \
  xargs -0 setfacl -Rm "$FACL_HTTPD_DEFAULT" &&
  echo " done."
}

#===  FUNCTION  ================================================================
#         NAME: ddm_ip_do_email
#  DESCRIPTION: Drop outgoing email ports.
#===============================================================================
ddm_ip_do_email ()
{
  printf "Dropping outoging SMTP (25, 2525, 587, 465, 2526)... "
  iptables -A OUTPUT -p tcp --dport 25 -j DROP
  iptables -A OUTPUT -p tcp --dport 2525 -j DROP
  iptables -A OUTPUT -p tcp --dport 587 -j DROP
  iptables -A OUTPUT -p tcp --dport 465 -j DROP
  iptables -A OUTPUT -p tcp --dport 2526 -j DROP
  iptables -A OUTPUT -p tcp --dport 993 -j DROP
  echo "ok."
}

#===  FUNCTION  ================================================================
#         NAME: ddm_ip_ai_nfs
#  DESCRIPTION: Accept incoming NFS (note custom NFS ports used).
#===============================================================================
ddm_ip_ai_nfs ()
{
  printf "Accepting NFS (custom: 2049, 111, 10000:10006)... "
  IN_NEW="-A INPUT -m state --state NEW"
  iptables "$IN_NEW" -m udp -p udp --dport 2049 -j ACCEPT
  iptables "$IN_NEW" -m tcp -p tcp --dport 2049 -j ACCEPT
  iptables "$IN_NEW" -m udp -p udp --dport 111 -j ACCEPT
  iptables "$IN_NEW" -m tcp -p tcp --dport 111 -j ACCEPT
  iptables "$IN_NEW" -m udp -p udp --dport 10000:10006 -j ACCEPT
  iptables "$IN_NEW" -m tcp -p tcp --dport 10000:10006 -j ACCEPT
  echo " done."
}

#===  FUNCTION  ================================================================
#         NAME: ddm_ip_ai_https
#  DESCRIPTION: Accept incoming HTTPS.
#===============================================================================
ddm_ip_ai_https()
{
  printf "Accepting HTTPS (443)... "
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  echo " done."
}

#===============================================================================
#
#                         Major / wrapper functions.
#
#===============================================================================

#===  FUNCTION  ================================================================
#         NAME: ddm_perms
#  DESCRIPTION: Wrapper to prompt for an item (if empty) and call ddm_context
#               and ddm_facl.
# PARAMATER $1: The path of the file or directory.
#===============================================================================
ddm_perms ()
{

  # Confirm run.
  read -p "Run ACL and/or CHCON? [Y/n]: " RUN_PERMS
  [[ ! "$RUN_PERMS" =~ (Y|y|) ]] && return 0

  # Get the item to set the permissions on.
  PERM_ITEM="$1"
  until [[ -f "$PERM_ITEM" || -d "$PERM_ITEM" ]]
  do read -p "`echo $'\n'`Enter an existing file or directory: " PERM_ITEM; done

  # Set the contexts if requested.
  read -p "Set contexts on $PERM_ITEM? [Y/n]: " SET_CONTEXTS
  [[ "$SET_CONTEXTS" =~ (Y|y|) ]]  && ddm_chcon "$PERM_ITEM"

  # Set the file ACLs if requested.
  read -p "Set file ACLs on $PERM_ITEM? [Y/n]: " SET_ACLS
  [[ "$SET_ACLS" =~ (Y|y|) ]]  && ddm_facl "$PERM_ITEM"
}

#===  FUNCTION  ================================================================
#         NAME:  ddm_httpd_vhost
#  DESCRIPTION:  Create an apache VirtualHost .conf file.
#===============================================================================
function ddm_httpd_vhost ()
{
  # Get shared variables.
  ddm_get_shared_vars

  # Prompts.
  read -p "Enter the httpd file prefix [005]: "          WEIGHT
  read -p "Enter the httpd listen port [8080]: "         PORT
  read -p "Enter the ServerAdmin [httpd@e9p.net]: "      SERVERADMIN
  read -p "Enter the DocumentRoot [$APP_ROOT/docroot]: " DOCUMENTROOT
  read -p "Enter the ServerName [$APP_NAME.com]: "       SERVERNAME
  read -p "Enter the ServerAlias (if any): "             SERVERALIAS

  # Defaults.
  WEIGHT=${WEIGHT:-005}
  PORT=${PORT:-8080}
  SERVERADMIN=${SERVERADMIN:-httpd@e9p.net}
  DOCUMENTROOT=${DOCUMENTROOT:-"$APP_ROOT/docroot"}
  SERVERNAME=${SERVERNAME:-"$APP_NAME.com"}

  # Basics.
  VHOST_CONTENT="
  <VirtualHost *:$PORT>

    # Basics.
    ServerAdmin $SERVERADMIN
    DocumentRoot $DOCUMENTROOT
    ServerName $SERVERNAME"

  # Add ServerAlias
  [ "$SERVERALIAS" != "" ] &&
  VHOST_CONTENT="$VHOST_CONTENT"$'\n'"ServerAlias $SERVERALIAS"

  # Enable rewrite engine.
  VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
    # Rewrite rules.
    RewriteEngine On"

  # Rewrite all aliases
  read -p "Rewrite all aliases to $SERVERNAME? [Y/n]" REWRITE_ALIAS
  [[ "$REWRITE_ALIAS" =~ (Y|y|) ]] && VHOST_CONTENT="$VHOST_CONTENT
    RewriteCond %{HTTP_HOST} !^$SERVERNAME [nocase]
    RewriteRule ^(.*)$ http://$SERVERNAME$1 [L,R=301]"

  # Logs
  VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
    # Logs.
    ErrorLog logs/$APP_NAME-error_log
    CustomLog logs/$APP_NAME-access_log common"

  # New Relic
  read -p "Set newrelic.appname to $APP_NAME? [Y/n]: " NEW_RELIC
  [[ "$NEW_RELIC" =~ (Y|y|) ]] && VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
    # New Relic Reporting.
    php_value newrelic.appname \"$APP_NAME\""

  # Opcache.
  VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
    # Disable opcache.
    # php_value opcache.revalidate_freq 0"

  # Close file.
  VHOST_CONTENT="$VHOST_CONTENT"$'\n'"</VirtualHost>"

  # Get location for VHOST file.
  VHOST_FILE_DEFAULT="/etc/httpd/conf.d/$WEIGHT-$APP_NAME.conf"
  read -p "`echo $'\n'`Conf location [$VHOST_FILE_DEFAULT]: " VHOST_FILE
  VHOST_FILE="${VHOST_FILE:=$VHOST_FILE_DEFAULT}"

  # Confirm write.
  echo "$VHOST_CONTENT"$'\n'
  read -p "Write above file to $VHOST_FILE? [Y/n]: " WRITE_FILE
  [[ ! "$WRITE_FILE" =~ (Y|y|) ]] &&
  echo "VirtualHost file not written, complete!" &&
  exit 0;

  # Write file.
  echo "$VHOST_CONTENT" > "$VHOST_FILE"
}

#===  FUNCTION  ================================================================
#         NAME:  ddm_import_archive
#  DESCRIPTION:  Prompts a user for a drush archive-dump file and configures
#                the database git repository / file directory.
#===============================================================================
ddm_import_archive ()
{
  # Get shared variables.
  ddm_get_shared_vars

  # Get the archive file.
  read -p "`echo $'\n'`Enter the path to the archive file: " ARCHIVE
  until [ -f "$ARCHIVE" ] && tar -tzf "$ARCHIVE" &> /dev/null
  do read -p "`echo $'\n'`Invalid file, please try again: " ARCHIVE; done

  # Get the database name.
  read -p "Enter the database name [${APP_NAME}_v1]: " DB_NAME
  DB_NAME="${DB_NAME:=${APP_NAME}_v1}"

  # Get the database user.
  read -p "Enter the database user name [$APP_NAME]: " DB_USER
  DB_USER="${DB_USER:=$APP_NAME}"

  # Get the database root password.
  read -sp "Enter the database root password:" DB_ROOT
  until [ "$DB_ROOT" != "" ] && mysql -u root -p"$DB_ROOT" -e ";" 2> /dev/null
  do read -sp "`echo $'\n'Could not connect, try again: `" DB_ROOT; done

  # Get the git repository URL.
  GIT_URL_DEFAULT="git@github.com:ElectronicPress/${APP_NAME}.git"
  read -p "`echo $'\n'`Enter the git repository url $GIT_URL_DEFAULT]: " GIT_URL
  GIT_URL="${GIT_URL:=$GIT_URL_DEFAULT}"

  # Check if the database exists already and confirm removal if so.
  DB_EXISTS=`mysql -uroot -p"$DB_ROOT" -N -e "SHOW DATABASES LIKE '$DB_NAME'"`

  [ "$DB_EXISTS" == "$DB_NAME" ] &&
  read -p "Database $DB_NAME already exists, overwrite? [y/N]: " REMOVE_DB &&
  [[ ! "$REMOVE_DB"  =~ (y|Y) ]] &&
  echo "Error: Database already exists." &&
  exit 1;

  # Check if the app root already exists and confirm removal if so.
  if [ -d "$APP_ROOT" ]; then
    read -p " $APP_ROOT already exists, overwrite? [y/N]: " REMOVE_APP_ROOT

    # User said don't remove app route.
    [[ ! "$REMOVE_APP_ROOT" =~ (y|Y) ]] &&
    echo "Error: directory already exists." &&
    exit 1;
  fi;



  # Create the create the database and set user priviliges.
  printf "Creating database $DB_NAME..."
  mysql -uroot -p"$DB_ROOT" -e \
    "GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost'\
     IDENTIFIED BY '${DB_USER}_localhost';"
  echo " done."

  # Remove existing approot.
  [ -d "$APP_ROOT" ] &&
  printf "Removing existing approot $APP_ROOT..." &&
  rm -rf "$APP_ROOT" &&
  echo " done."

  # Create new approot, change to it.
  printf "Creating approot $APP_ROOT..."
  mkdir -p "$APP_ROOT" && cd "$APP_ROOT"
  echo " done."

  # Import the site archive.
  printf "Restoring $ARCHIVE to $APP_ROOT..."
  drush arr "$ARCHIVE" --destination="$APP_ROOT"/docroot &> /dev/null
  echo " done."

  # Initialize git, add the origin, and pull.
  printf "Configuring git..."
  git init &> /dev/null
  git remote add origin "$GIT_URL" &> /dev/null
  git pull origin master &> /dev/null
  echo " done."
}

#===  FUNCTION  ================================================================
#         NAME: ddm_iptables
#  DESCRIPTION: Sets the system IP tables with prompts for common ports.
#===============================================================================
ddm_iptables()
{
  # Flush and set defaults
  printf "Flushing... "
  iptables -F
  echo " done."

  # Accept ssh.
  printf "Accepting ssh on 2086... "
  iptables -A INPUT -p tcp --dport 2086 -j ACCEPT
  echo " done."

  # Defaults.
  printf "Setting default chains (DROP INPUT/FORWARD, ACCEPT OUTPUT)... "
  iptables -P INPUT DROP
  iptables -P FORWARD DROP
  iptables -P OUTPUT ACCEPT
  echo " done."

  # Accept rsync (drush).
  printf "Accepting rsync on 873 (drush)... "
  iptables -A INPUT -p tcp --dport 873 -j ACCEPT
  echo " done."

  # Accept http.
  printf "Accepting http on 80... "
  iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  echo " done."

  # Accept Loopback & established.
  printf "Accepting loopback and established... "
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  echo " done."

  # Prompts.
  read -p "Drop outgoing emails? [y/N]: " DROP_EMAIL
  [[ "$DROP_EMAIL" =~ (y|Y) ]] && ddm_ip_do_email

  read -p "Accept NFS? [y/N]: "  ACCEPT_NFS
  [[ "$ACCEPT_NFS" =~ (y|Y) ]] && ddm_ip_ai_nfs

  read -p "Accept HTTPS? [y/N]: "  ACCEPT_HTTPS
  [[ "$ACCEPT_HTTPS" =~ (y|Y) ]] && ddm_ip_ai_https

  # Save & list.
  printf "Saving... "
  /sbin/service iptables save
  iptables -L -nv
  echo " done."
}

#===============================================================================
#
#                         Runtime functionality.
#
#===============================================================================

# Must be root.
[ "$(id -u)" != "0" ] && echo "Please run as root." && exit 1

# Validate argument.
[[ ! "$#" -eq 1 || ! "$1" =~ (m|p|h|i) ]] &&
  echo "Usage: ddm [(m)igrate|(p)ermissions|(h)ttpd VirtualHost|(i)ptables]" &&
  exit 1

# Run selected functionality.
case "$1" in

i) # Configure iptables.
   ddm_iptables
;;

p) # Configure permissions.
   ddm_perms
;;

h) # Create a VirtualHost.
   ddm_httpd_vhost
   ddm_perms "$VHOST_FILE"
;;

m) # Perform the initial migration of a site from a different environment.
   ddm_import_archive
   ddm_perms "$APP_ROOT"
   ddm_httpd_vhost
   ddm_perms "$VHOST_FILE"
;;

esac

# Done without errors.
exit 0;
