FROM IMAGE_PATH

RUN mkdir -p /opt/dataease/plugins/default

ADD plugins/default/*  /opt/dataease/plugins/default

