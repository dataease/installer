FROM registry.cn-qingdao.aliyuncs.com/dataease/dataease:IMAGE_TAG

RUN mkdir -p /opt/dataease/plugins/default

ADD plugins/default/*  /opt/dataease/plugins/default

