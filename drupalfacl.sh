#!/bin/bash
#
# Must be root
#
[ "$(id -u)" != "0" ] && { printf "Please run as root."; exit 1 }
#
# Must be one argument
#
[ "$#" -ne 1 ] && { echo "Usage: drupalfacl [path]"; exit 1 }
#
# Set target to second argument, default to html folder.
#
TARGET=${1:-/var/www/html}
#
# Ensure valid target directory.
#
[ ! -d "$TARGET" ] && { echo "The directory \`$TARGET\` does not exist."; exit 1 }
#
# Set SELinux contexts.
#
selinux_chcon ()
{
  ENFORCE=/selinux/enforce &&
    [ -f "$ENFORCE" ] &&
    [ `cat "$ENFORCE"` == 1 ] &&
    chcon -R system_u:object_r:httpd_sys_content_t:s0 "$TARGET" &&
    echo "Contexts set"
}
#
# Initialize the webroot acl.
#
facl_webroot ()
{
  # Get acl file.
  ACL="`pwd`/webroot.acl"

  # Set global webroot ACL
  [ ! -f "$ACL" ] &&
    echo "Could not find webroot.acl.  Using defaults." &&
    setfacl -Rbm u::rwX,g::---,o::---,g:web-user:r-X,g:web-admin:rwX,m::rwx,d:u::rwX,d:g::---,d:o::---,d:g:web-user:r-X,d:g:web-admin:rwX,d:m::rwx "$TARGET" ||
    setfacl -RbM "$ACL" "$TARGET"

  # Success.
  echo "Directory \`$TARGET\` initialized."
}
#
# Sets the files directory acls.
#
facl_files ()
{
  # Get acl file.
  ACL="`pwd`/files.acl"

  # Set files directory ACLs.
  [ ! -f "$ACL" ] &&
    echo "Could not find files.acl.  Using defaults." &&
    find "$TARGET" -path "*sites/default/files" -print0 | xargs -0 setfacl -Rbm g:web-drupal:rwX,d:g:web-drupal:rwX ||
    find "$TARGET" -path "*sites/default/files" -print0 | xargs -0 setfacl -RbM "$ACL"

  # Success.
  echo "File directory acl's set."
}
#
# Prompts.
#
read -p "Set SELinux Contexts? [Y/n]: " SET_SELINUX_CHCON; [[ "$SET_SELINUX_CHCON" =~ (y|Y|) ]] && selinux_chcon
read -p "Set ACLs on $TARGET? [Y/n]: "  SET_FACL_WEBROOT;  [[ "$SET_FACL_WEBROOT" =~ (y|Y|) ]]  && facl_webroot
read -p "Set ACLS on sites/default/files? [Y/n]: " SET_FACL_FILES; [[ "$SET_FACL_WEBROOT" =~ (y|Y|) ]] && facl_files
#
# Done.
#
echo "Complete!"
exit 0;
