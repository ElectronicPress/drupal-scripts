#!/bin/bash
#
# Must be root
#
[ "$(id -u)" != "0" ] && { echo "Please run as root."; exit 1; }
#
# Prompts.
#
read -p "Enter the app name: "                               APP_NAME     && [ -z "$APP_NAME" ] && { echo "App name required."; exit 1; }
read -p "Enter the httpd file prefix [005]: "                WEIGHT       && WEIGHT=${WEIGHT:-005}
read -p "Enter the httpd listen port [8080]: "               PORT         && PORT=${PORT:-8080}
read -p "Enter the ServerAdmin [httpd@e9p.net]: "            SERVERADMIN  && SERVERADMIN=${SERVERADMIN:-httpd@e9p.net}
read -p "Enter the DocumentRoot [/var/www/html/$APP_NAME]: " DOCUMENTROOT && DOCUMENTROOT=${DOCUMENTROOT:-/var/www/html/"$APP_NAME"}
read -p "Enter the ServerName [$APP_NAME.com]: "             SERVERNAME   && SERVERNAME=${SERVERNAME:-"$APP_NAME.com"}
read -p "Enter the ServerAlias (if any): "                   SERVERALIAS
#
# Basics.
#
VHOST_CONTENT="
<VirtualHost *:$PORT>

  # Basics.
  ServerAdmin $SERVERADMIN
  DocumentRoot $DOCUMENTROOT
  ServerName $SERVERNAME"
#
# Add ServerAlias
#
[ "$SERVERALIAS" != "" ] && VHOST_CONTENT="$VHOST_CONTENT"$'\n'"ServerAlias $SERVERALIAS"
#
# Enable rewrite engine.
#
VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
  # Rewrite rules.
  RewriteEngine On"
#
# Rewrite all aliases
#
read -p "Rewrite all aliases to $SERVERNAME? [Y/n]" REWRITE_ALIAS
[[ "$REWRITE_ALIAS" =~ (Y|y|) ]] && VHOST_CONTENT="$VHOST_CONTENT
  RewriteCond %{HTTP_HOST} !^$SERVERNAME [nocase]
  RewriteRule ^(.*)$ http://$SERVERNAME$1 [L,R=301]"
#
# Logs
#
VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
  # Logs.
  ErrorLog logs/$APP_NAME-error_log
  CustomLog logs/$APP_NAME-access_log common"
#
# New Relic
#
read -p "Set newrelic.appname to $APP_NAME? [Y/n]: " NEW_RELIC
[[ "$NEW_RELIC" =~ (Y|y|) ]] && VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
  # New Relic Reporting.
  php_value newrelic.appname \"$APP_NAME\""
#
# Opcache.
#
VHOST_CONTENT="$VHOST_CONTENT"$'\n'"
  # Disable opcache.
  # php_value opcache.revalidate_freq 0"
#
# Close file.
#
VHOST_CONTENT="$VHOST_CONTENT"$'\n'"</VirtualHost>"
#
# Target file
#
TARGET="/etc/httpd/conf.d/$WEIGHT-$APP_NAME.conf"
#
# Confirm write.
#
echo "$VHOST_CONTENT"$'\n'
read -p "Write above file to $TARGET? [Y/n]: " WRITE_FILE && [[ ! "$WRITE_FILE" =~ (Y|y|) ]] && { echo "VirtualHost file not written, complete!"; exit 0; }
#
# Write file, set contexts.
#
echo "$VHOST_CONTENT" > "$TARGET" && chcon system_u:object_r:httpd_config_t:s0 "$TARGET"
#
# Done.
#
printf "\nComplete!\n"
exit 0;
