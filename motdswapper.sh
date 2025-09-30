#!/bin/bash

# ========================

mkdir -p motdswapper-bkp
if [[ -f /usr/local/bin/motd.sh ]]; then
    echo "Salvando backup de /usr/local/bin/motd.sh em motdswapper-bkp/"
    cp /usr/local/bin/motd.sh motdswapper-bkp/
fi

echo "Instalando motd.sh em /usr/local/bin/motd.sh"
cp motd.sh /usr/local/bin/motd.sh
chmod +x /usr/local/bin/motd.sh

if [[ -f /etc/motd ]]; then
    echo "Salvando backup de /etc/motd em motdswapper-bkp/"
    cp /etc/motd motdswapper-bkp/
    rm -f /etc/motd
fi

