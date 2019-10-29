#!/bin/sh

#Seafile initialisation and start script
VERSION_FILE=".seafile_version"

# Make sure, that /usr/local/bin is in PATH
# (it shoul be there and without it,
#  but I want to be sure, because of
#  all seafile utilites are in /usr/local/bin)
PATH=${PATH}:/usr/local/bin

if [[ ! -z "$MYSQL_HOST" ]]; then
    # Wait for containers
    while ! mysqladmin ping --host $MYSQL_HOST --port $MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS --silent; do
      sleep 2
    done
fi

SEAFILE_VERSION=`cat /seafile/version`
if [ -z "$SEAFILE_VERSION" ]; then
	echo "can not find Seafile version in file /seafile/version, probably corrupted image"
	exit 1
fi

source /etc/profile.d/seafile.sh

#Just in case
cd /seafile

#Seafile-server related enviroment variables
CCNET_CONF_DIR=/seafile/data/ccnet
export CCNET_CONF_DIR
SEAFILE_CONF_DIR=/seafile/data/seafile-data
export SEAFILE_CONF_DIR
SEAFILE_CENTRAL_CONF_DIR=/seafile/data/conf
export SEAFILE_CENTRAL_CONF_DIR

# If there is $VERSION_FILE already, then it isn't first run of this script,
#  do not need to configure seafile
if [ ! -f data/$VERSION_FILE ]; then
	echo 'No previous version on Seafile configurations found, starting seafile configuration...'

	# Init ccnet
	if [ ! -d 'data/ccnet' ]; then

		ccnet-init -F ${SEAFILE_CENTRAL_CONF_DIR} -c ${CCNET_CONF_DIR} --name "$SERVER_NAME" --port 10001 --host "$SERVER_DOMAIN" || exit 3

		if [ ! -z "$MYSQL_HOST" ]; then
		    echo "[Database]
ENGINE = mysql
HOST = $MYSQL_HOST
PORT = $MYSQL_PORT
USER = $MYSQL_USER
PASSWD = $MYSQL_PASS
DB = ccnet
CONNECTION_CHARSET = utf8" >> /seafile/data/conf/ccnet.conf
		fi

		echo '* ccnet configured successfully'
	fi

	# Init seafile
	if [ ! -d "data/seafile-data" ]; then
		seaf-server-init -F ${SEAFILE_CENTRAL_CONF_DIR} --seafile-dir ${SEAFILE_CONF_DIR} --port 12001 --fileserver-port 8082 || exit 4
		echo "${SEAFILE_CONF_DIR}" > ${CCNET_CONF_DIR}/seafile.ini
		if [ ! -z "$MYSQL_HOST" ]; then
		    echo "[database]
type = mysql
host = $MYSQL_HOST
port = $MYSQL_PORT
user = $MYSQL_USER
password = $MYSQL_PASS
db_name = seafile
connection_charset = utf8" >> /seafile/data/conf/seafile.conf
		fi

		echo '* seafile configured successfully'
	fi

	# Init seahub
	if [ ! -f "data/conf/seahub_settings.py" ]; then
		SKEY1=`uuidgen -r`
		SKEY2=`uuidgen -r`
		SKEY=`echo "$SKEY1$SKEY2" | cut -c1-40`
		echo "SECRET_KEY = '${SKEY}'" > ${SEAFILE_CENTRAL_CONF_DIR}/seahub_settings.py
		if [ ! -z "$MYSQL_HOST" ]; then
            echo "DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql', # Add 'postgresql_psycopg2', 'mysql', 'sqlite3' or 'oracle'.
        'NAME': 'seahub', # Or path to database file if using sqlite3.
        'USER': '$MYSQL_USER',                      # Not used with sqlite3.
        'PASSWORD': '$MYSQL_PASS',                  # Not used with sqlite3.
        'HOST': '$MYSQL_HOST',                      # Set to empty string for localhost. Not used with sqlite3.
        'PORT': '$MYSQL_PORT',                      # Set to empty string for default. Not used with sqlite3.
    }
}" >> ${SEAFILE_CENTRAL_CONF_DIR}/seahub_settings.py
        else
            echo "DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3', # Add 'postgresql_psycopg2', 'mysql', 'sqlite3' or 'oracle'.
        'NAME': '/seafile/data/seahub.db', # Or path to database file if using sqlite3.
        'USER': '',                      # Not used with sqlite3.
        'PASSWORD': '',                  # Not used with sqlite3.
        'HOST': '',                      # Set to empty string for localhost. Not used with sqlite3.
        'PORT': '',                      # Set to empty string for default. Not used with sqlite3.
    }
}" >> ${SEAFILE_CENTRAL_CONF_DIR}/seahub_settings.py
        fi
		echo '* seahub configured successfully'
	fi

  mysql -h $MYSQL_HOST --port $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS ccnet < /seafile/seafile-server/scripts/sql/mysql/ccnet.sql
  sed -i 's/%ADMIN_EMAIL%/'$SEAFILE_ADMIN_EMAIL'/' /seafile/seafile-admin.sql
  sed -i 's/%ADMIN_PASSWORD%/'$SEAFILE_ADMIN_PASSWORD'/' /seafile/seafile-admin.sql
  mysql -h $MYSQL_HOST --port $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS ccnet < /seafile/seafile-admin.sql
	echo '* ccnet database synchronized successfully'

  mysql -h $MYSQL_HOST --port $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS seafile < /seafile/seafile-server/scripts/sql/mysql/seafile.sql
	echo '* seafile database synchronized successfully'

  mysql -h $MYSQL_HOST --port $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASS seahub < /seafile/seafile-server/seahub/sql/mysql.sql
	echo '* seahub database synchronized successfully'

    chown -R seafile:seafile /seafile/
    chown -R seafile:seafile /tmp/seahub_cache

	# Keep seafile version for managing future updates
	echo -n "${SEAFILE_VERSION}" > data/$VERSION_FILE
	echo "Configuration completed!"

else #[ ! -f $VERSION_FILE ];
	# Need to check if we need to run upgrade scripts
	echo "Version file found in container, checking it"
	OLD_VER=`cat data/$VERSION_FILE`
	if [ "x$OLD_VER" != "x$SEAFILE_VERSION" ]; then
		echo "Version is different. Stored version is $OLD_VER, Current version is $SEAFILE_VERSION"
		if [ -f '.no-update' ]; then
			echo ".no-update file found, skipping update"
			echo "You should update user data manually (or delete file .no-update)"
			echo "  do not forget to update seafile version in $VERSION_FILE manually after update"
		else
			echo "No .no-update file found, performing update..."

			# Get first and second numbers of versions (we do not care about last number, actually)
			OV1=`echo "$OLD_VER" | cut -d. -f1`
			OV2=`echo "$OLD_VER" | cut -d. -f2`
			#OV3=`echo "$OLD_VER" | cut -d. -f3`
			CV1=`echo "$SEAFILE_VERSION" | cut -d. -f1`
			CV2=`echo "$SEAFILE_VERSION" | cut -d. -f2`
			#CV3=`echo "$SEAFILE_VERSION" | cut -d. -f3`

			i1=$OV1
			i1p=$i1
			i2p=$OV2
			i2=`expr $i2p '+' 1`
			while [ $i1 -le $CV1 ]; do
				SCRIPT="./seafile-server/scripts/upgrade/upgrade_${i1p}.${i2p}_${i1}.${i2}.sh"
				if [ -f $SCRIPT ]; then
                    echo "Upgrading database from version ${i1p}.${i2p} to ${i1}.${i2}"

                    db_update_helper=./seafile-server/scripts/upgrade/db_update_helper.py
                    if ! python2.7 "${db_update_helper}" ${i1}.${i2}.0; then
                        echo "Failed to upgrade your database"
                    fi

					i1p=$i1
					i2p=$i2
					i2=`expr "$i2" '+' 1`
				else
					i1p=$i1
					i1=`expr "$i1" '+' 1`
					i2=0
				fi
			done

            chown -R seafile:seafile /seafile/

			echo -n "${SEAFILE_VERSION}" > data/$VERSION_FILE
		fi
	else
		echo "Version is the same, no upgrade needed"
	fi
fi

# migrate avatars on every start
mkdir -p /seafile/data/seahub-data/avatars
mv -f seafile-server/seahub/media/avatars/* /seafile/data/seahub-data/avatars/ 2>/dev/null 1>&2
rm -rf seafile-server/seahub/media/avatars
ln -s /seafile/data/seahub-data/avatars /seafile/seafile-server/seahub/media/avatars

# create media custom directory symlink on every start
mkdir -p /seafile/data/seahub-data/custom
ln -s /seafile/data/seahub-data/custom /seafile/seafile-server/seahub/media/custom

if [[ "$ENABLE_SEAFDAV" = "true" ]]; then

    echo "
[program:seafdav]
directory=/seafile/
command=bash -c \"python -m wsgidav.server.run_server --log-file /seafile/logs/seafdav.log --pid /seafile/pids/seafdav.pid --port 8080 --host 0.0.0.0\"
user=seafile
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
environment=SEAHUB_DIR="/seafile/seafile-server/seahub"

" >> /etc/supervisord.conf

fi

exec "$@"