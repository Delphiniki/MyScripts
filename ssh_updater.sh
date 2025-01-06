#!/bin/bash

# This script upgrades openssh package to version 9.9p1
### Created by Nikolay Chotrov ###

sudo apt update && \
sudo apt install build-essential zlib1g-dev libssl-dev -y && \
sudo mkdir /var/lib/sshd
sudo chmod -R 700 /var/lib/sshd/
sudo chown -R root:sys /var/lib/sshd/

cd /tmp
wget -c https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.9p1.tar.gz
sshfile=$(sudo find ./ -type f -name "openssh-*.tar.gz")
tar -xzf $sshfile
sshdir=$(sudo find ./ -type d -name "openssh-*")
cd $sshdir
sudo apt install libpam0g-dev libselinux1-dev libkrb5-dev -y && \
sudo ./configure --with-kerberos5 --with-md5-passwords --with-pam --with-selinux --with-privsep-path=/var/lib/sshd/ --sysconfdir=/etc/ssh
sudo make
sudo -uroot make install
exit 0
