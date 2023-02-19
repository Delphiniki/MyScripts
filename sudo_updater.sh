#!/bin/bash

sudo apt-get update -y && \
tempd=$(mktemp -d)
cd $tempd
wget https://www.sudo.ws/dist/sudo.tar.gz
tar -zxvf ./sudo.tar.gz
#echo "Done with extraction of files!"
sudodir=$(find ./ -type d -name 'sudo-*')
#echo $lastdir1
cd $sudodir
#echo $(pwd)
sudo -uroot ./configure --prefix=/usr --libexecdir=/usr/lib --with-secure-path --with-all-insults --with-env-editor --docdir=/usr/share/doc/$sudodir --with-passprompt="[sudo] password for %p: "
sudo -uroot make
sudo -uroot make install && sudo -uroot ln -sfv libsudo_util.so.0.0.0 /usr/lib/sudo/libsudo_util.so.0

