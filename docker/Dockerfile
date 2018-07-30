FROM alpine:3.4
MAINTAINER Jan Rohwer <jan@rohwer.online>

# SEAFILE_VERSION:
# Seafile-Server version do townload and install
#  See https://github.com/haiwen/seafile-server/releases
#  for latest avaliable version
ENV	SEAFILE_VERSION="6.2.5"
ENV LIBEVHTP_VERSION="1.2.10"
ENV LIBSEARPC_VERSION="3.1-latest"

# Fix little bug in alpine image
RUN ln -s /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh

################################
# Install some needed packages #
################################
RUN apk update
###########################################
# Runtime dependencies for Seafile-Server #
# bash is needed for upgrade scripts      #
###########################################
RUN apk add bash openssl python py-setuptools py-imaging sqlite \
    libevent util-linux glib jansson libarchive \
		mariadb-client-libs postgresql-libs py-pillow py-mysqldb mariadb-client syslog-ng supervisor

#################################################
# Add build-deps for Seafile-Server             #
#################################################
RUN apk add --virtual .build_dep \
    curl-dev libevent-dev glib-dev util-linux-dev intltool \
    sqlite-dev libarchive-dev libtool jansson-dev vala fuse-dev \
    cmake make musl-dev gcc g++ automake autoconf bsd-compat-headers \
    python-dev file mariadb-dev mariadb-dev py-pip git

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
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

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
RUN cd seahub-${SEAFILE_VERSION}-server/ && pip install -r requirements.txt && \
    pip install gunicorn django-picklefield requests flup==1.0.3.dev-20110405  && \
    cd .. && mv seahub-${SEAFILE_VERSION}-server seafile-server/seahub

RUN mkdir /seafile/seafile-server/runtime
COPY seahub.conf /seafile/seafile-server/runtime/seahub.conf

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

RUN ldconfig || true

##############################
# Do some preparations       #
# Like add seafile user and  #
#  create his home directory #
##############################
RUN addgroup -g 2016 seafile
RUN adduser -D -s /bin/sh -g "Seafile Server" -G seafile -h /seafile -u 2016 seafile

# Store seafile version
RUN mkdir -p /var/lib/seafile && echo -n "$SEAFILE_VERSION" > /var/lib/seafile/version

# Container initialization scripts ()
COPY docker-entrypoint.sh /
COPY syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf

RUN mkdir /seafile/logs && \
    mkdir /seafile/pids && \
    mkdir /seafile/data && \
    chown -R seafile:seafile /seafile

EXPOSE 8000 8082

VOLUME /seafile/data

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

#########################################
# Delete all unneded files and packages #
#########################################
RUN cd / \
   apk del --purge .build_dep \
   rm /var/cache/apk/* \
   rm -rf /root/.cache \
   rm /*.tar.gz \
