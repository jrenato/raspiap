#!/bin/bash
###################################################
#set default values
###################################################

# Network Interface
#IP4_CONF_TYPE=DHCP
IP4_ADDRESS=192.168.1.1
IP4_RANGE_START=192.168.1.10
IP4_RANGE_END=192.168.1.200
IP4_NETMASK=255.255.255.0
#IP4_GATEWAY=192.168.0.1
#IP4_DNS1=8.8.8.8.8
#IP4_DNS2=4.4.4.4

# Wifi Access Point
AP_WIFACE=wlan0
AP_EIFACE=eth0
AP_COUNTRY=BR
AP_CHAN=1
AP_SSID=RPiAP
AP_PASSPHRASE=PASSWORD

###################################################
echo " performing a series of prechecks..."
###################################################

#check current user privileges
(( `id -u` )) && echo "This script MUST be ran with root privileges, try prefixing with sudo. i.e sudo $0" && exit 1

#check that internet connection is available

# the hosts below are selected for their high availability,
# if it is more apprioriate to change a host to equal one that is
# required for the script then simply change the FQDN chosen below
# to check the availabilty for the host before the script gets underway

host1=google.com
host2=wikipedia.org
((ping -w5 -c3 $host1 || ping -w5 -c3 $host2) > /dev/null 2>&1) && echo "Internet connectivity - OK" || (echo "Internet connectivity - Down, Internet connectivity is required for this script to complete. exiting..." && exit 1)

#pre-checks complete#####################################################

#clear the screen
clear

# Get Input from User
echo "Capture User Settings:"
echo "====================="
echo
echo "Please answer the following questions."
echo "Hitting return will continue with the default option"
echo
echo

EIFACES=()
WIFACES=()

for n in "/sys/class/net"/*
do
  filename=`basename $n`
  type=`echo $filename | cut -c1-3`
  if [ "$type" = "eth" ]; then EIFACES+=$filename; fi
  if [ "$type" = "wla" ]; then WIFACES+=$filename; fi
done

if [ ${#EIFACES[@]} = 0 ]; then
  echo "No ethernet interfaces found"
  exit
fi

if [ ${#WIFACES[@]} = 0 ]; then
  echo "No wireless interfaces found"
  exit
fi

echo "Select your ethernet interface"
select AP_EIFACE in "${EIFACES[@]}"; do
  if [ "$AP_EIFACE" != "" ]; then
    echo "$AP_EIFACE selected"
    break
  fi
  echo "Invalid option, try again"
done

echo "Select your wireless interface"
select AP_WIFACE in "${WIFACES[@]}"; do
  if [ "$AP_WIFACE" != "" ]; then
    echo "$AP_WIFACE selected"
    break
  fi
  echo "Invalid option, try again"
done

read -p "IPv4 Address [$IP4_ADDRESS]: " -e t1
if [ -n "$t1" ]; then IP4_ADDRESS="$t1"; fi

read -p "IPv4 Address [$IP4_RANGE_START]: " -e t1
if [ -n "$t1" ]; then IP4_RANGE_START="$t1"; fi

read -p "IPv4 Address [$IP4_RANGE_END]: " -e t1
if [ -n "$t1" ]; then IP4_RANGE_END="$t1"; fi

read -p "IPv4 Netmask [$IP4_NETMASK]: " -e t1
if [ -n "$t1" ]; then IP4_NETMASK="$t1";fi

read -p "Wifi Country [$AP_COUNTRY]: " -e t1
if [ -n "$t1" ]; then AP_COUNTRY="$t1";fi

read -p "Wifi Channel Name [$AP_CHAN]: " -e t1
if [ -n "$t1" ]; then AP_CHAN="$t1";fi

read -p "Wifi SSID [$AP_SSID]: " -e t1
if [ -n "$t1" ]; then AP_SSID="$t1";fi

read -s -p "Wifi PassPhrase (min 8 max 63 characters) [$AP_PASSPHRASE]: " -e t1
if [ -n "$t1" ]; then AP_PASSPHRASE="$t1";fi

###################################################
# Get Decision from User
###################################################

echo "Access Point"
echo "======================"
echo "Please answer the following question."
echo "Hitting return will continue with the default 'No' option"
echo

# Point of no return
read -p "Do you wish to continue and Setup RPi as an Access Point? (y/n) " RESP
if [ "$RESP" = "y" ]; then

clear
echo "Configuring RPI as an Access Point...."
# update system
echo ""
echo "#####################PLEASE WAIT##################"######
echo -en "Package list update                                 "
apt-get -qq update && apt-get upgrade
echo -en "[OK]\n"

echo -en "Adding packages                                     "
apt-get -y -qq install rfkill zd1211-firmware hostapd hostap-utils iw dnsmasq
echo -en "[OK]\n"

if [ ! -f /etc/hostapd/hostapd.conf ]; then
echo "Backup: hostapd.conf.ap.bak"
mv /etc/hostapd/hostapd.conf /etc/hostapd.conf.ap.bak
fi

#create the hostapd configuration to match what the user has provided
echo -en "Create hostapd.conf file                            "
cat <<EOF > /etc/hostapd/hostapd.conf
#created by $0
interface=$AP_WIFACE
driver=nl80211
country_code=$AP_COUNTRY
ssid=$AP_SSID
channel=$AP_CHAN
wpa=3
wpa_passphrase=$AP_PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
EOF
  rc=$?
  if [[ $rc != 0 ]] ; then
    echo -en "[FAIL]\n"
    echo ""
    exit $rc
  else
    echo -en "[OK]\n"
  fi

# backup the existing interfaces file
if [ ! -f /etc/network/interfaces.ap.bak ]; then
  echo -en "Backup network interface configuration              "
  mv /etc/network/interfaces /etc/network/interfaces.ap.bak
fi

# create the following network interface file based on user input
echo -en "Create new network interface configuration          "
cat <<EOF > /etc/network/interfaces
#created by $0
auto lo
allow-hotplug $AP_WIFACE
allow-hotplug $AP_EIFACE

iface lo inet loopback
iface $AP_EIFACE inet dhcp
iface $AP_WIFACE inet static
hostapd /etc/hostapd/hostapd.conf

address $IP4_ADDRESS
netmask $IP4_NETMASK
EOF
  rc=$?
  if [[ $rc != 0 ]] ; then
    echo -en "[FAIL]\n"
    echo ""
    exit $rc
  else
    echo -en "[OK]\n"
  fi

# create the following network interface file based on user input
if [ ! -f /etc/dnsmasq.conf.ap.bak ]; then
  echo "Backup dnsmasq.conf"
  mv /etc/dnsmasq.conf /etc/dnsmasq.conf.ap.bak
fi
echo -en "Create new dnsmasq configuration                    "
cat <<EOF > /etc/dnsmasq.conf
#created by $0
domain-needed
interface=$AP_WIFACE
dhcp-range=$IP4_RANGE_START,$IP4_RANGE_END,12h
#dhcp-option=252,"\n"
EOF
  rc=$?
  if [[ $rc != 0 ]] ; then
    echo -en "[FAIL]\n"
    echo ""
    exit $rc
  else
    echo -en "[OK]\n"
  fi

echo -en "Create new init file                                "
cat <<EOF > /etc/init.d/pipoint
#!/bin/bash

### BEGIN INIT INFO
# Provides: pipoint
# Required-Start:    $local_fs $syslog $remote_fs dbus
# Required-Stop:     $local_fs $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start pipoint
### END INIT INFO

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o $AP_EIFACE -j MASQUERADE
iptables -A FORWARD -i $AP_EIFACE -o $AP_WIFACE -m state --state RELATED,ESTABLISHED -j AC$
iptables -A FORWARD -i $AP_WIFACE -o $AP_EIFACE -j ACCEPT
EOF
  rc=$?
  if [[ $rc != 0 ]] ; then
    echo -en "[FAIL]\n"
    echo ""
    exit $rc
  else
    echo -en "[OK]\n"
  fi

chmod +x /etc/init.d/pipoint
update-rc.d pipoint defaults
update-rc.d hostapd enable

ifdown $AP_WIFACE
ifup $AP_WIFACE
service hostapd restart
service dnsmasq restart

fi
