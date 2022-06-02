
DEVERSION=$(curl -s https://api.github.com/repos/dataease/dataease/releases/latest | grep -e "\"tag_name\"" | sed -r 's/.*: "(.*)",/\1/')

echo "开始下载 DataEase ${DEVERSION} 版本在线安装包"

dataease_online_file_name="dataease-${DEVERSION}-online.tar.gz"
download_url="https://github.com/dataease/dataease/releases/download/${DEVERSION}/${dataease_online_file_name}"

echo "下载地址： ${download_url}"

curl -LOk -m 60 -o ${dataease_online_file_name} ${download_url}

if [ ! -f ${dataease_online_file_name} ];then
	echo "下载在线安装包失败，请试试重新执行一次安装命令。"
	exit 1
fi

tar zxvf ${dataease_online_file_name}
if [ $? != 0 ];then
	echo "下载在线安装包失败，请试试重新执行一次安装命令。"
	rm -f ${dataease_online_file_name}
	exit 1
fi
cd dataease-${DEVERSION}-online

/bin/bash install.sh