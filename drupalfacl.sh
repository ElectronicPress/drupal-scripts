#!/bin/bash

# Must be at least one argument
if [ "$#" -lt 1 ]; then
  echo "Usage: drupalfacl [w webroot|f files] [path]"
  exit 1
fi

# Set target to second argument, default to html folder.
target=${2:-/var/www/html}

# Ensure valid target directory.
if [ ! -d "$target" ]; then
  echo "The directory \`$target\` was not found"
  exit 1
fi

# Set contexts.
selinux_chcon ()
{
  ENFORCE=/selinux/enforce
  if [ -f "$ENFORCE" ] &&  [ `cat "$ENFORCE"` == 1 ]; then
    chcon -R system_u:object_r:httpd_sys_content_t:s0 "$target"
    echo "Contexts set"
  fi
}

# Initialize the webroot acl.
facl_webroot ()
{
  # Get acl file.
  acl="`pwd`/webroot.acl"

  # Set global webroot ACL
  if [ ! -f "$acl" ]
    then echo "Could not find webroot.acl.  Using defaults." && \
         setfacl -Rbm u::rwX,g::---,o::---,g:web-user:r-X,g:web-admin:rwX,m::rwx,d:u::rwX,d:g::---,d:o::---,d:g:web-user:r-X,d:g:web-admin:rwX,d:m::rwx "$target"
    else setfacl -RbM "$acl" "$target"
  fi

  # Success.
  echo "Directory \`$target\` initialized."
}

# Sets the files directory acls.
facl_files ()
{
  # Get acl file.
  acl="`pwd`/files.acl"

  # Set files directory ACLs.
  if [ ! -f "$acl" ]
    then echo "Could not find files.acl.  Using defaults." && \
         find "$target" -path "*sites/default/files" -print0 | xargs -0 setfacl -Rbm g:web-drupal:rwX,d:g:web-drupal:rwX "$target"
    else find "$target" -path "*sites/default/files" -print0 | xargs -0 setfacl -RbM "$acl" "$target"
  fi
  echo "File directory acl's set."
}

# Switch argument.
case "$1" in
w) selinux_chcon; facl_webroot; facl_files;;
f) selinux_chcon; facl_files;;
*) echo "Usage: drupalfacl [w webroot|f files] [path]"; exit 1;;
esac

exit 0;
