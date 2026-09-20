#!/bin/bash

#export NO_CACHE="--no-cache"
#export MAKE_OPT="-j4"

cd $PFBENCH
cd subjects/FTP/LightFTP
docker build . -t hnp-lightftp -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-lightftp-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/FTP/BFTPD
docker build . -t hnp-bftpd -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-bftpd-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/FTP/ProFTPD
docker build . -t hnp-proftpd -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-proftpd-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/FTP/PureFTPD
docker build . -t hnp-pureftpd -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-pureftpd-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/SMTP/Exim
docker build . -t hnp-exim -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-exim-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/DNS/Dnsmasq
docker build . -t hnp-dnsmasq -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-dnsmasq-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/RTSP/Live555
docker build . -t hnp-live555 -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-live555-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/SIP/Kamailio
docker build . -t hnp-kamailio -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-kamailio-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/SSH/OpenSSH
docker build . -t hnp-openssh -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-openssh-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/TLS/OpenSSL
docker build . -t hnp-openssl -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-openssl-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/DTLS/TinyDTLS
docker build . -t hnp-tinydtls -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-tinydtls-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/DICOM/Dcmtk
docker build . -t hnp-dcmtk -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-dcmtk-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

cd $PFBENCH
cd subjects/DAAP/forked-daapd
docker build . -t hnp-forked-daapd -f Dockerfile-aflnet --build-arg $MAKE_OPT $NO_CACHE
docker build . -t hnp-forked-daapd-stateafl -f Dockerfile-stateafl --build-arg $MAKE_OPT $NO_CACHE

