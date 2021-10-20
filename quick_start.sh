#Install Latest Stable DataEase Release

git_urls=('github.com' 'hub.fastgit.org')

for git_url in ${git_urls[*]}
do
	success="true"
	for i in {1..3}
	do
		echo -ne "检测 ${git_url} ... ${i} "
	    curl -m 5 -kIs https://${git_url} >/dev/null
		if [ $? != 0 ];then
			echo "failed"
			success="false"
			break
		else
			echo "ok"
		fi
	done
	if [ ${success} == "true" ];then
		server_url=${git_url}
		break
	fi
done

if [ 'x${server_url}' == 'x' ];then
    echo "没有找到稳定的下载服务器，请稍候重试"
    exit 1
fi


echo "使用下载服务器 ${server_url}"

DEVERSION=$(curl -s https://${server_url}/dataease/dataease/releases/latest/download 2>&1 | grep -Po 'v[0-9]+\.[0-9]+\.[0-9]+.*(?=")')

curl -LOk https://${server_url}/dataease/dataease/releases/latest/download/dataease-${DEVERSION}-online.tar.gz

if [ ! -f dataease-${DEVERSION}-online.tar.gz ];then
	echo "下载在线安装包失败，请试试重新执行一次安装命令。"
	exit 1
fi

tar zxvf dataease-${DEVERSION}-online.tar.gz
if [ $? != 0 ];then
	echo "下载在线安装包失败，请试试重新执行一次安装命令。"
	rm -f dataease-${DEVERSION}-online.tar.gz
	exit 1
fi
cd dataease-${DEVERSION}-online

/bin/bash install.sh