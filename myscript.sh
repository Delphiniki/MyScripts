#!/bin/bash

sudo apt-get update
tempd=$(mktemp -d)
cd $tempd
echo $(pwd)
sleep 2
wget https://www.sudo.ws/dist/sudo.tar.gz
tar -zxvf ./sudo.tar.gz
echo "Done with extraction of files!"
sleep 2
lastdir1=$(find ./ -type d -name 'sudo-*')
#echo $lastdir1
cd $lastdir1
echo $(pwd)
sleep 2
sudo -uroot ./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path --with-all-insults --with-env-editor --docdir=/usr/share/doc/$lastdir --with-passprompt="[sudo] password for %p: "
sudo -uroot make
sudo -uroot make install && sudo -uroot ln -sfv libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0

