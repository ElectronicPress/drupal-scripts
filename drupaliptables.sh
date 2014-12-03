#!/bin/bash
#
# Must be root
#
[ "$(id -u)" != "0" ] && { echo "Please run as root."; exit 1; }

echo "done!"
exit 0;
