#!/bin/bash

CURRENT_DIR=$(
   cd "$(dirname "$0")"
   pwd
)

function log() {
   message="[DATAEASE Log]: $1 "
   echo -e "${message}" 2>&1 | tee -a ${CURRENT_DIR}/install.log
}

args=$@
os=`uname -a`
docker_config_folder="/etc/docker"
compose_files="-f docker-compose.yml -f docker-compose-kettle-doris.yml"

if [ -f /usr/bin/dectl ]; then
   # 获取已安装的 DataEase 的运行目录
   DE_BASE=`grep "^DE_BASE=" /usr/bin/dectl | cut -d'=' -f2`
fi

set -a
if [[ $DE_BASE ]] && [[ -f $DE_BASE/dataease/.env ]]; then
   source $DE_BASE/dataease/.env
else
   source ${CURRENT_DIR}/install.conf
fi
set +a

DE_RUN_BASE=$DE_BASE/dataease
conf_folder=${DE_RUN_BASE}/conf
templates_folder=${DE_RUN_BASE}/templates

echo -e "======================= 开始安装 =======================" 2>&1 | tee -a ${CURRENT_DIR}/install.log

mkdir -p ${DE_RUN_BASE}
cp -r ./dataease/* ${DE_RUN_BASE}/

cd $DE_RUN_BASE
env | grep DE_ >.env

mkdir -p $conf_folder
mkdir -p ${DE_RUN_BASE}/data/kettle
mkdir -p ${DE_RUN_BASE}/data/fe
mkdir -p ${DE_RUN_BASE}/data/be
mkdir -p ${DE_RUN_BASE}/data/mysql

if [ ${DE_EXTERNAL_MYSQL} = "false" ]; then
   compose_files="${compose_files} -f docker-compose-mysql.yml"
else
   sed -i -e "/^    depends_on/,+2d" docker-compose.yml
fi


log "拷贝配置文件模板文件  -> $conf_folder"
cd $DE_RUN_BASE
cp -r $templates_folder/* $conf_folder
cp -r $templates_folder/.kettle $conf_folder

log "根据安装配置参数调整配置文件"
cd ${templates_folder}
templates_files=( dataease.properties mysql.env )
for i in ${templates_files[@]}; do
   if [ -f $i ]; then
      envsubst < $i > $conf_folder/$i
   fi
done


cd ${CURRENT_DIR}
sed -i -e "s#DE_BASE=.*#DE_BASE=${DE_BASE}#g" dectl
\cp dectl /usr/local/bin && chmod +x /usr/local/bin/dectl
if [ ! -f /usr/bin/dectl ]; then
  ln -s /usr/local/bin/dectl /usr/bin/dectl 2>/dev/null
fi

echo "time: $(date)"

if which getenforce && [ $(getenforce) == "Enforcing" ];then
   log  "... 关闭 SELINUX"
   setenforce 0
   sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
fi

#Install docker & docker-compose
##Install Latest Stable Docker Release
if which docker >/dev/null; then
   log "检测到 Docker 已安装，跳过安装步骤"
   log "启动 Docker "
   service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker"
      cp docker/bin/* /usr/bin/
      cp docker/service/docker.service /etc/systemd/system/
      chmod +x /usr/bin/docker*
      chmod 754 /etc/systemd/system/docker.service
      log "... 启动 docker"
      systemctl enable docker; systemctl daemon-reload; service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
   else
      log "... 在线安装 docker"
      curl -fsSL https://get.docker.com -o get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
      sudo sh get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
      log "... 启动 docker"
      systemctl enable docker; systemctl daemon-reload; service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
   fi

   if [ ! -d "$docker_config_folder" ];then
      mkdir -p "$docker_config_folder"
   fi

   docker version >/dev/null
   if [ $? -ne 0 ]; then
      log "docker 安装失败"
      exit 1
   else
      log "docker 安装成功"
   fi
fi

##Install Latest Stable Docker Compose Release
docker-compose version >/dev/null
if [ $? -ne 0 ]; then
   if [[ -d docker ]]; then
      log "... 离线安装 docker-compose"
      cp docker/bin/docker-compose /usr/bin/
      chmod +x /usr/bin/docker-compose
   else
      log "... 在线安装 docker-compose"
      curl -L https://get.daocloud.io/docker/compose/releases/download/1.29.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose 2>&1 | tee -a ${CURRENT_DIR}/install.log
      chmod +x /usr/local/bin/docker-compose
      ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   fi

   docker-compose version >/dev/null
   if [ $? -ne 0 ]; then
      log "docker-compose 安装失败"
      exit 1
   else
      log "docker-compose 安装成功"
   fi
else
   log "检测到 Docker Compose 已安装，跳过安装步骤"
fi

export COMPOSE_HTTP_TIMEOUT=180
cd ${CURRENT_DIR}
# 加载镜像
if [[ -d images ]]; then
   log "加载镜像"
   for i in $(ls images); do
      docker load -i images/$i 2>&1 | tee -a ${CURRENT_DIR}/install.log
   done
else
   log "拉取镜像"
   cd ${DE_RUN_BASE} && docker-compose $compose_files pull 2>&1
   cd -
fi

log "配置 dataease Service"
cp ${DE_RUN_BASE}/bin/dataease/dataease.service /etc/init.d/dataease
chmod a+x /etc/init.d/dataease
if which chkconfig;then
   chkconfig --add dataease
fi

if [ -f /etc/rc.d/rc.local ];then
   dataeaseService=`grep "service dataease start" /etc/rc.d/rc.local | wc -l`
   if [ "$dataeaseService" -eq 0 ]; then
      echo "sleep 10" >> /etc/rc.d/rc.local
      echo "service dataease start" >> /etc/rc.d/rc.local
   fi
   chmod +x /etc/rc.d/rc.local
fi

if [ `grep "vm.max_map_count" /etc/sysctl.conf | wc -l` -eq 0 ];then
   sysctl -w vm.max_map_count=262144
   echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi

if [ `grep "net.ipv4.ip_forward" /etc/sysctl.conf | wc -l` -eq 0 ];then
   sysctl -w net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
else
   sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
fi

if which firewall-cmd >/dev/null; then
   if systemctl is-active firewalld &>/dev/null ;then
      log "防火墙端口开放"
      firewall-cmd --zone=public --add-port=80/tcp --permanent
      firewall-cmd --reload
   else
      log "防火墙未开启，忽略端口开放"
   fi
fi


log "启动服务"
cd ${DE_RUN_BASE} && docker-compose $compose_files up -d 2>&1 | tee -a ${CURRENT_DIR}/install.log

dectl status 2>&1 | tee -a ${CURRENT_DIR}/install.log

for b in {1..30}
do
   sleep 3
   http_code=`curl -sILw "%{http_code}\n" http://localhost:${DE_PORT} -o /dev/null`
   if [[ $http_code == 000 ]];then
      log "服务启动中，请稍候 ..."
   elif [[ $http_code == 200 ]];then
      log "服务启动成功!"
      break;
   else
      log "服务启动出错!"
      exit 1
   fi
done

if [[ $http_code != 200 ]];then
   log "等待时间内未完全启动，请稍后使用 dectl status 检查服务运行状况。"
fi

echo -e "======================= 安装完成 =======================\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log
echo -e "请通过以下方式访问:\n URL: http://\$LOCAL_IP:$DE_PORT\n 用户名: admin\n 初始密码: dataease" 2>&1 | tee -a ${CURRENT_DIR}/install.log

