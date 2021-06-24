#!/bin/bash
MYSQL_HOST=mysql
MYSQL_SCHEMA=dataease
MYSQL_USER=root
MYSQL_PASSWD=Password123@mysql

DE_RUN_BASE=/opt/dataease

CURRENT_DIR=$(
   cd "$(dirname "$0")"
   pwd
)

args=$@
os=`uname -a`
docker_config_folder="/etc/docker"
compose_files="-f docker-compose.yml"
conf_folder=${DE_RUN_BASE}/conf
templates_folder=${DE_RUN_BASE}/templates

reinstall_or_upgrade="n"
if [[ -f /usr/bin/dectl ]];then
   reinstall_or_upgrade="y"
else
   read -p "是否使用内建 MySQL, 外部数据库仅支持 MySQL: (y/n, 默认y)"  build_in_database

   if [[ -z "${build_in_database}" || "${build_in_database}" == "y" ]];then
    build_in_database='y'
   else
    build_in_database='n'
   fi

   if [[ "${build_in_database}" == "n" ]];then
     read -p "Mysql database address: "  MYSQL_HOST
     read -p "Mysql database schema: "  MYSQL_SCHEMA
     read -p "Mysql database user: "  MYSQL_USER
     read -p "Mysql database password: "  MYSQL_PASSWD
   fi
fi


function log() {
   message="[DATAEASE Log]: $1 "
   echo -e "${message}" 2>&1 | tee -a ${CURRENT_DIR}/install.log
}

echo -e "======================= 开始安装 =======================" 2>&1 | tee -a ${CURRENT_DIR}/install.log

mkdir -p ${DE_RUN_BASE}
cp -r ./dataease/* ${DE_RUN_BASE}/

mkdir -p $conf_folder
mkdir -p ${DE_RUN_BASE}/data/kettle

if [[ "${reinstall_or_upgrade}" == "n" ]];then
   sed -i -e "s/MYSQL_HOST/${MYSQL_HOST}/g" $templates_folder/dataease.properties
   sed -i -e "s/MYSQL_SCHEMA/${MYSQL_SCHEMA}/g" $templates_folder/dataease.properties
   sed -i -e "s/MYSQL_USER/${MYSQL_USER}/g" $templates_folder/dataease.properties
   sed -i -e "s/MYSQL_PASSWD/${MYSQL_PASSWD}/g" $templates_folder/dataease.properties
   sed -i -e "s/MYSQL_PASSWD/${MYSQL_PASSWD}/g" $templates_folder/mysql.env

   log "拷贝主配置文件 dataease.properties -> $conf_folder"
   cp -r $templates_folder/dataease.properties $conf_folder

   if [[ "${build_in_database}" == "y" ]];then
      log "拷贝 mysql 配置文件  -> $conf_folder"
      cp -r $templates_folder/mysql.env $conf_folder
      cp -r $templates_folder/my.cnf $conf_folder
      mkdir -p ${DE_RUN_BASE}/data/mysql
   fi
fi

if [[ -z "${build_in_database}" || "${build_in_database}" == "y" ]];then
   build_in_database='y'
   compose_files="${compose_files} -f docker-compose-mysql.yml"
fi


cp -r $templates_folder/version $conf_folder


log "拷贝 kettle,doris 配置文件  -> $conf_folder"
cp -r $templates_folder/be.conf $conf_folder
cp -r $templates_folder/fe.conf $conf_folder
cp -r $templates_folder/.kettle $conf_folder
mkdir -p ${DE_RUN_BASE}/data/fe
mkdir -p ${DE_RUN_BASE}/data/be
compose_files="${compose_files} -f docker-compose-kettle-doris.yml"

cd ${CURRENT_DIR}


\cp dectl /usr/local/bin && chmod +x /usr/local/bin/dectl
if [ ! -f /usr/bin/dectl ]; then
  ln -s /usr/local/bin/dectl /usr/bin/dectl 2>/dev/null
fi

sed -i "/#!\/bin\/bash/a build_in_database=${build_in_database}" /usr/local/bin/dectl

echo "time: $(date)"

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
fi

##Install Latest Stable Docker Compose Release
if which docker-compose >/dev/null; then
   log "检测到 Docker Compose 已安装，跳过安装步骤"
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker-compose"
      cp docker/bin/docker-compose /usr/bin/
      chmod +x /usr/bin/docker-compose
   else
      log "... 在线安装 docker-compose"
      COMPOSEVERSION=$(curl -s https://github.com/docker/compose/releases/latest/download 2>&1 | grep -Po [0-9]+\.[0-9]+\.[0-9]+)
      curl -L "https://github.com/docker/compose/releases/download/$COMPOSEVERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>&1 | tee -a ${CURRENT_DIR}/install.log
      chmod +x /usr/local/bin/docker-compose
      ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   fi
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
   cd ${DE_RUN_BASE} && docker-compose $compose_files pull 2>&1 | tee -a ${CURRENT_DIR}/install.log
   cd -
fi

log "配置 dataease Service"
cp ${DE_RUN_BASE}/bin/dataease/dataease.service /etc/init.d/dataease
chmod a+x /etc/init.d/dataease
chkconfig --add dataease

dataeaseService=`grep "service dataease start" /etc/rc.d/rc.local | wc -l`
if [ "$dataeaseService" -eq 0 ]; then
   echo "sleep 10" >> /etc/rc.d/rc.local
   echo "service dataease start" >> /etc/rc.d/rc.local
fi
chmod +x /etc/rc.d/rc.local
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

echo -e "======================= 安装完成 =======================\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log
echo -e "请通过以下方式访问:\n URL: http://\$LOCAL_IP\n 用户名: admin\n 初始密码: dataease" 2>&1 | tee -a ${CURRENT_DIR}/install.log
echo -e "您可以使用命令 'dectl status' 检查服务运行情况.\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log-a ${CURRENT_DIR}/install.log

