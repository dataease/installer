#Install Latest Stable DataEase Release

DEVERSION=$(curl -s https://github.com/dataease/dataease/releases/latest/download 2>&1 | grep -Po 'v[0-9]+\.[0-9]+\.[0-9]+.*(?=")')

wget --no-check-certificate https://github.com/dataease/dataease/releases/latest/download/dataease-release-${DEVERSION}.tar.gz

if [ ! -f dataease-release-${DEVERSION}.tar.gz ];then
	echo "下载在线安装包失败，请试试重新执行一次安装命令。"
	exit 1
fi
tar zxvf dataease-release-${DEVERSION}.tar.gz
cd dataease-release-${DEVERSION}

/bin/bash install.sh