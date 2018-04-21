#/tftpboot/images/c7.ks
#for VB
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use HTTP installation media
url --url="http://192.168.142.101/images/centos7"
# Use text mode install
text
# Root password

# Network information
network --bootproto=dhcp --device=enp0s9 --onboot=yes --activate
%include /tmp/network.ks
# System authorization information
auth useshadow passalgo=sha512
# Run the Setup Agent on first boot disabled by default
firstboot --disabled
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --permissive
# Installation logging level
logging --level=debug
# Reboot after installation
reboot
# System timezone
timezone  Europe/Moscow
# Use only sda&sdb
ignoredisk --only-use=sda,sdb
# System bootloader configuration
bootloader --location=mbr --driveorder=sda,sdb
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --drives=sda,sdb --all
# Disk partitioning
# RAID parts
part raid.01 --fstype="raid" --ondisk=sda --size=1024
part raid.02 --fstype="raid" --grow --ondisk=sda --size=1
part raid.03 --fstype="raid" --ondisk=sdb --size=1024
part raid.04 --fstype="raid" --grow --ondisk=sdb --size=1
# PV and partitions
raid /boot --device=md0 --fstype="ext4" --level=1 raid.01 raid.03
raid pv.01 --device=md1 --level=1 raid.02 raid.04
# VG
volgroup centos pv.01
# LV
logvol swap --vgname="centos" --size=1024 --name="lv_swap"
logvol / --vgname="centos" --size=3072 --grow --name="lv_root" --fstype="ext4"
logvol /var --vgname="centos" --size=1024 --name="lv_var" --fstype="ext4"
# Services
services --enabled=network --disabled=NetworkManager
# Install packages
%packages
@^minimal
%end


%pre

#getting netinfo by user
hostname=""
ipaddress=""
netmask=""
servIP=""
(echo -n "Enter hostname: ") >/dev/tty1 </dev/tty1
read hostname
(echo -n "Enter IP address (x.x.x.x) : ") >/dev/tty1 </dev/tty1
read ipaddress
(echo -n "Enter netmask (x.x.x.x): ") >/dev/tty1 </dev/tty1
read netmask
(echo -n "Enter service IP (x.x.x.x): ") >/dev/tty1 </dev/tty1
read servIP
# getting iface names
firstNetworkIntName=$(ip l | grep enp | awk 'NR==1' | awk -F ":" {'print $2'} | awk '{$1=$1};1')
secondNetworkIntName=$(ip l | grep enp | awk 'NR==2' | awk -F ":" {'print $2'} | awk '{$1=$1};1')
(echo -n "First net interface is: $firstNetworkIntName; ") >/dev/tty1 </dev/tty1
(echo -n "Second net interface is: $secondNetworkIntName; ") >/dev/tty1 </dev/tty1
# sign
(echo -n "All set. Enter to check data...") >/dev/tty1 </dev/tty1
read
# putting data for post-script
echo "hostname=$hostname
ipaddress=$ipaddress
netmask=$netmask
serviceIP=$servIP
firstiface=$firstNetworkIntName
secondiface=$secondNetworkIntName" > /dataforPost
(cat /dataforPost) >/dev/tty1 </dev/tty1
(echo -n "/dataforPost has been recorded. Enter to continue and apply config...") >/dev/tty1 </dev/tty1
read
# putting data for main ks-script
echo "network --bootproto=static --device=$firstNetworkIntName --onboot=yes --activate --noipv6 --ip=$ipaddress --netmask=$netmask --hostname=$hostname" > /tmp/network.ks
(cat /tmp/network.ks) >/dev/tty1 </dev/tty1
(echo "/tmp/network.ks has been recorded.
Enjoy installing :)") >/dev/tty1 </dev/tty1
%end


%post --nochroot
cp /dataforPost /mnt/sysimage/dataforPost
%end


%post

# Install bonding
modprobe --first-time  bonding
echo "alias bond0 bonding" > /etc/modprobe.d/bonding.conf

# Configure first interface
firstiface=$(cat /dataforPost | grep firstiface | awk -F= '{print $NF}')
echo -e "TYPE=Ethernet
DEVICE=$firstiface
NAME=$firstiface
BOOTPROTO=none
ONBOOT=yes
MASTER=bond0
SLAVE=yes
NM_CONTROLLED=no
USERCTL=no" > /etc/sysconfig/network-scripts/ifcfg-$firstiface

# Configure second interface
secondiface=$(cat /dataforPost | grep secondiface | awk -F= '{print $NF}')
echo -e "TYPE=Ethernet
DEVICE=$secondiface
NAME=$secondiface
BOOTPROTO=none
ONBOOT=yes
MASTER=bond0
SLAVE=yes
NM_CONTROLLED=no
USERCTL=no" > /etc/sysconfig/network-scripts/ifcfg-$secondiface

# Configure bond0 interface

ipaddress=$(cat /dataforPost | grep ipaddress | awk -F= '{print $NF}')
netmask=$( cat /dataforPost | grep netmask | awk -F= '{print $NF}')
echo -e "DEVICE=bond0
NAME=bond0
TYPE=Bond
BONDING_MASTER=yes
IPADDR=$ipaddress
NETMASK=$netmask
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
BONDING_OPTS=\"mode=0 miimon=100 fail_over_mac=1\"
NM_CONTROLLED=no
HOTPLUG=yes" > /etc/sysconfig/network-scripts/ifcfg-bond0

systemctl restart network


# Install mysshauth
mkdir /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqR4eBoaeAIlX80PxQvU26ozd86NMLnbpg82IHxOW/EYuz1tuWUzdkq3eJoCK6Cwdy/bU1PAlRslexdXSfuhYWZaXDMeyLSSZzgxLQoTDzaC6w0HR6xeZUAzEWl2i54Fk4afBIoUBqgxVwzC9uh1uG/ntfVwXGQ3ZvZWWO9JSWf0U0Hrmz9JRqH1E5WJWTmDYJJhoxwu3lwot2tGiHeIowCRzEGNuVF9Pn2GlBp81vgI2itAebS5r67ksfONvmXvDr+W6hW5qzO0RC7P/Jlg2dFWPtcmeuJNbr9Z77odsyDtH77QQ/yWVm9wlHFrSYLoCtkHPZHJj60QFnmuVbcsnaQ== rsa-key-20180316" > /root/.ssh/authorized_keys
chmod -R 700 /root/.ssh


# Install myservices
yum install vim htop epel-release tcpdump telnet nmap -y
yum install nginx -y


# Install announcing
yum install bird -y
systemctl enable bird
echo "alias dummy0 dummy" >> /etc/modprobe.d/bonding.conf
echo \#\!/bin/bash >  /etc/sysconfig/modules/dummy.modules
echo "modprobe dummy
exit 0" >> /etc/sysconfig/modules/dummy.modules
echo "options dummy numdummies=1" > /etc/modprobe.d/dummy.conf

# Configure dummy0 interface
serviceIP=$(cat /dataforPost | grep serviceIP | awk -F= '{print $NF}')
echo -e "NAME=dummy0
DEVICE=dummy0
IPADDR=$serviceIP
NETMASK=255.255.255.255
ONBOOT=yes
TYPE=Ethernet
NM_CONTROLLED=no
NOZEROCONF=yes" > /etc/sysconfig/network-scripts/ifcfg-dummy0

# Make reserve copy of original bird.conf
cp /etc/bird.conf /root/firstbird.conf

# Configure new bird.conf
hardifaces=${firstiface%??}*
echo -e "protocol device {
        scan time 10;
        }

        protocol direct {
                interface \"dummy*\";
                }

        protocol rip MyRIP {
                period 5;
                export all;
                import all;
                interface \"bond0\" { mode multicast; };
                interface \"$hardifaces\" { mode quiet; };
        }" > /etc/bird.conf
systemctl restart network
systemctl start bird

%end
