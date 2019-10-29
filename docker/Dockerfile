FROM alpine:latest AS build
MAINTAINER Jan Rohwer <jan@rohwer.online>

# SEAFILE_VERSION:
# Seafile-Server version do townload and install
#  See https://github.com/haiwen/seafile-server/releases
#  for latest avaliable version
ARG	SEAFILE_VERSION="7.0.5"
ARG LIBEVHTP_VERSION="1.2.10"
ARG LIBSEARPC_VERSION="3.1-latest"
ARG PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

#################################################
# Add build-deps for Seafile-Server             #
#################################################
RUN apk add -U --no-cache --virtual .build_dep \
    curl-dev libevent-dev glib-dev util-linux-dev intltool \
    sqlite-dev libarchive-dev libtool jansson-dev vala fuse-dev \
    cmake make musl-dev gcc g++ automake autoconf bsd-compat-headers \
    python-dev file mariadb-dev mariadb-dev py-pip git openssl jpeg-dev zlib-dev libxml2-dev libxslt-dev

WORKDIR /seafile

####################
# Install libevhtp #
####################
RUN wget https://github.com/criticalstack/libevhtp/archive/${LIBEVHTP_VERSION}.tar.gz -O- | tar xzf - \
    && cd libevhtp-${LIBEVHTP_VERSION}/ && cmake -DEVHTP_DISABLE_SSL=ON -DEVHTP_BUILD_SHARED=ON . && make -j4 && make install && cp oniguruma/onigposix.h /usr/include/ \
    && cd .. && rm -rf libevhtp-${LIBEVHTP_VERSION}

###################################
# Download all Seafile components #
###################################
RUN wget https://github.com/haiwen/libsearpc/archive/v${LIBSEARPC_VERSION}.tar.gz -O- | tar xzf - \
    && wget https://github.com/haiwen/ccnet-server/archive/v${SEAFILE_VERSION}-server.tar.gz -O- | tar xzf - \
    && wget https://github.com/haiwen/seafile-server/archive/v${SEAFILE_VERSION}-server.tar.gz -O- | tar xzf - \
    && wget https://github.com/haiwen/seahub/archive/v${SEAFILE_VERSION}-server.tar.gz -O- | tar xzf - \
    && wget https://github.com/haiwen/seafobj/archive/v${SEAFILE_VERSION}-server.tar.gz -O- | tar xzf - \
    && wget https://github.com/haiwen/seafdav/archive/v${SEAFILE_VERSION}-server.tar.gz -O- | tar xzf -

###############################
# Build and install libSeaRPC #
###############################
RUN cd libsearpc-${LIBSEARPC_VERSION}/ && ./autogen.sh && ./configure && make -j4 && make install && \
    cd .. && rm -rf libsearpc-${LIBSEARPC_VERSION}

###########################
# Build and install CCNET #
###########################
RUN cd ccnet-server-${SEAFILE_VERSION}-server/ && \
	./autogen.sh && \
    ./configure --with-mysql --with-postgresql --enable-python && \
		make -j4 && make install && cd .. && rm -rf ccnet-server-${SEAFILE_VERSION}-server

####################################
# Build and install Seafile-Server #
# As a First step we need to patch #
# seafile-controller topdir        #
# And some scripts                 #
####################################
RUN cd seafile-server-${SEAFILE_VERSION}-server/ && \
    ./autogen.sh && \
    ./configure --with-mysql --with-postgresql --enable-python && \
		make -j4 && make install && \
	cd .. && mv seafile-server-${SEAFILE_VERSION}-server seafile-server

# copy seahub to subdirectory of seafile-server
RUN cd seahub-${SEAFILE_VERSION}-server/ && \
    cd .. && mv seahub-${SEAFILE_VERSION}-server seafile-server/seahub

RUN cd seafile-server/seahub && \
    pip install -r requirements.txt --prefix /usr/local && \
    pip install --prefix /usr/local gunicorn django-picklefield requests flup SQLAlchemy

###########
# SeafObj #
###########
RUN cd seafobj-${SEAFILE_VERSION}-server/ && \
    mv seafobj /usr/local/lib/python2.7/site-packages && cd .. && rm -rf seafobj-${SEAFILE_VERSION}-server

###########
# SeafDav #
###########
RUN cd seafdav-${SEAFILE_VERSION}-server/ && \
    mv wsgidav /usr/local/lib/python2.7/site-packages && cd .. && rm -rf seafdav-${SEAFILE_VERSION}-server

RUN echo -n "$SEAFILE_VERSION" > /seafile/version

RUN mkdir /seafile/logs && \
    mkdir /seafile/pids && \
    mkdir /seafile/data

FROM alpine:latest
MAINTAINER Jan Rohwer <jan@rohwer.online>

ENV SERVER_NAME="Seafile"
ENV SERVER_DOMAIN="seafile.domain.com"
ENV MYSQL_HOST=""
ENV MYSQL_PORT="3306"
ENV MYSQL_USER="seafile"
ENV MYSQL_PASS="seafile"
ENV ENABLE_SEAFDAV="false"

###########################################
# Runtime dependencies for Seafile-Server #
# bash is needed for upgrade scripts      #
###########################################
RUN ln -s /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
    apk -U --no-cache add bash openssl python py-setuptools py-imaging sqlite \
        libevent util-linux glib jansson libarchive libjpeg libxml2 libxslt \
	    postgresql-libs py-pillow py-mysqldb mariadb-client syslog-ng supervisor tini

WORKDIR /seafile

RUN echo $'export PYTHONPATH=/usr/lib/python2.7/site-packages/:/usr/local/lib/python2.7/site-packages/:/seafile/seafile-server/seahub/thirdpart\n \
export SEAHUB_LOG_DIR=/seafile/logs\n \
export CCNET_CONF_DIR=/seafile/data/ccnet\n \
export SEAFILE_CONF_DIR=/seafile/data/seafile-data\n \
export SEAFILE_CENTRAL_CONF_DIR=/seafile/data/conf' >> /etc/profile.d/seafile.sh

##############################
# Do some preparations       #
# Like add seafile user and  #
#  create his home directory #
##############################
RUN addgroup -g 2016 seafile && \
    adduser -D -s /bin/sh -g "Seafile Server" -G seafile -h /seafile -u 2016 seafile

COPY --from=build /seafile/ /seafile/
COPY --from=build /usr/local /usr/local

# Container initialization scripts ()
COPY docker-entrypoint.sh /
COPY syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
COPY supervisord.conf /etc/supervisord.conf
COPY seahub.conf /seafile/seahub.conf
COPY seafile-admin.sql /seafile/seafile-admin.sql

RUN chown -R seafile:seafile /seafile && \
    chmod +x /docker-entrypoint.sh

EXPOSE 8000 8082 8080

VOLUME /seafile/data

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]
CMD exec /usr/bin/supervisord -c /etc/supervisord.conf
