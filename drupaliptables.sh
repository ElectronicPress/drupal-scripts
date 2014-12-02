#!/bin/bash
#
# Must be root
#
[ "$(id -u)" != "0" ] && { printf "Please run as root."; exit 1; }
#
# Drop email ports.
#
drop_email ()
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
#
# Accept NFS (note custom NFS ports used).
#
accept_nfs ()
{
  printf "Accepting NFS (custom: 2049, 111, 10000:10006)... "
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 2049 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 2049 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 111 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 111 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m udp -p udp --dport 10000:10006 -j ACCEPT
  iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 10000:10006 -j ACCEPT
  echo "ok."
}
#
# Accept HTTPS
#
accept_https()
{
  printf "Accepting HTTPS (443)... "
  iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  echo "ok."
}
#
# Flush and set defaults
#
printf "Flushing... "
iptables -F
echo "ok."
#
# Accept ssh.
#
printf "Accepting ssh on 2086... "
iptables -A INPUT -p tcp --dport 2086 -j ACCEPT
echo "ok."
#
# Defaults.
#
printf "Setting default chains (DROP INPUT/FORWARD, ACCEPT OUTPUT)... "
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
echo "ok."
#
# Accept rsync (drush).
#
printf "Accepting rsync on 873 (drush)... "
iptables -A INPUT -p tcp --dport 873 -j ACCEPT
echo "ok."
#
# Accept http.
#
printf "Accepting http on 80... "
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
echo "ok."
#
# Accept Loopback & established.
#
printf "Accepting loopback and established... "
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "ok."
#
# Prompts.
#
read -p "Drop outgoing emails? [y/N]: " DROP_EMAIL;   [[ "$DROP_EMAIL"   =~ (y|Y) ]] && drop_email
read -p "Accept NFS? [y/N]: "           ACCEPT_NFS;   [[ "$ACCEPT_NFS"   =~ (y|Y) ]] && accept_nfs
read -p "Accept HTTPS? [y/N]: "         ACCEPT_HTTPS; [[ "$ACCEPT_HTTPS" =~ (y|Y) ]] && accept_https
#
# Save & list.
#
printf "Saving... "
/sbin/service iptables save
iptables -L -nv
echo "done!"
exit 0;
