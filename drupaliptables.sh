#!/bin/bash

#
# Must be root
#
if [ "$(id -u)" != "0" ]; then
  echo "Please run as root."
  exit 1
fi

#
# Must be one argument
#
if [ ! "$#" -eq 1 ]; then
  echo "Please specify [d]ev, [s]tage, or [p]rod."
  exit 1
fi

#
# Ensure valid argument.
#
if [ "$1" -ne "d" ] && [ "$1" -ne "s" ] && [ "$1" -ne "p" ]; then
  echo "Please specify [d]ev, [s]tage, or [p]rod."
  exit 1
fi

# Flush all current rules from iptables.
iptables -F

# Accept ssh.
iptables -A INPUT -p tcp --dport 2086 -j ACCEPT

# Defaults.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Accept rsync (drush).
iptables -A INPUT -p tcp --dport 873 -j ACCEPT

# Accept Loopback & established.
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Drop email ports.
drop_email ()
{
  iptables -A OUTPUT -p tcp --dport 25 -j DROP
  iptables -A OUTPUT -p tcp --dport 2525 -j DROP
  iptables -A OUTPUT -p tcp --dport 587 -j DROP
  iptables -A OUTPUT -p tcp --dport 465 -j DROP
  iptables -A OUTPUT -p tcp --dport 2526 -j DROP
  iptables -A OUTPUT -p tcp --dport 993 -j DROP
}

# Accept NFS (note custom NFS ports used).
accept_nfs ()
{
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 2049 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 2049 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 111 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 111 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 10000:10006 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 10000:10006 -j ACCEPT
}

# Switch argument.
case "$1" in
d) accept_nfs
   drop_email
   iptables -A INPUT -p tcp --dport 80 -j ACCEPT;;

s) drop_email
   iptables -A INPUT -p tcp --dport 8080 -j ACCEPT;;

p) iptables -A INPUT -p tcp --dport 8080 -j ACCEPT;;
esac

# Save & list.
/sbin/service iptables save
iptables -L -n -v
exit 0;
