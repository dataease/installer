#Install Latest Stable DataEase Release

DEVERSION=$(curl -s https://github.com/dataease/dataease/releases/latest/download 2>&1 | grep -Po 'v[0-9]+\.[0-9]+\.[0-9]+.*(?=")')

wget --no-check-certificate https://github.com/dataease/dataease/releases/latest/download/dataease-release-${DEVERSION}.tar.gz
tar zxvf dataease-release-${DEVERSION}.tar.gz
cd dataease-release-${DEVERSION}

/bin/bash install.sh