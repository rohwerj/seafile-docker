#!/bin/sh

#Seafile initialisation and start script
VERSION_FILE=".seafile_version"

# Make sure, that /usr/local/bin is in PATH
# (it shoul be there and without it,
#  but I want to be sure, because of
#  all seafile utilites are in /usr/local/bin)
PATH=${PATH}:/usr/local/bin

# Wait for containers
while ! mysqladmin ping --host mysql -useafile -pseafile --silent; do
  sleep 2
done

SEAFILE_VERSION=`cat /var/lib/seafile/version`
if [ -z "$SEAFILE_VERSION" ]; then
	echo "can not find Seafile version in file /var/lib/seafile/version, probably corrupted image"
	exit 1
fi

source /etc/profile.d/seahub.sh

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
        [ -z "$SERVER_NAME"   ] && SERVER_NAME="Seafile"
        [ -z "$SERVER_DOMAIN" ] && SERVER_DOMAIN="seafile.domain.com"

		ccnet-init -F ${SEAFILE_CENTRAL_CONF_DIR} -c ${CCNET_CONF_DIR} --name "$SERVER_NAME" --port 10001 --host "$SERVER_DOMAIN" || exit 3
		echo '* ccnet configured successfully'
	fi

	# Init seafile
	if [ ! -d "data/seafile-data" ]; then
		seaf-server-init -F ${SEAFILE_CENTRAL_CONF_DIR} --seafile-dir ${SEAFILE_CONF_DIR} --port 12001 --fileserver-port 8082 || exit 4
		echo "${SEAFILE_CONF_DIR}" > ${CCNET_CONF_DIR}/seafile.ini
		echo '* seafile configured successfully'
	fi

	# Init seahub
	if [ ! -f "data/conf/seahub_settings.py" ]; then
		SKEY1=`uuidgen -r`
		SKEY2=`uuidgen -r`
		SKEY=`echo "$SKEY1$SKEY2" | cut -c1-40`
		echo "SECRET_KEY = '${SKEY}'

ADMINS = (
    # ('Your Name', 'your_email@domain.com'),
)

MANAGERS = ADMINS

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3', # Add 'postgresql_psycopg2', 'mysql', 'sqlite3' or 'oracle'.
        'NAME': '/seafile/data/seahub.db', # Or path to database file if using sqlite3.
        'USER': '',                      # Not used with sqlite3.
        'PASSWORD': '',                  # Not used with sqlite3.
        'HOST': '',                      # Set to empty string for localhost. Not used with sqlite3.
        'PORT': '',                      # Set to empty string for default. Not used with sqlite3.
    }
}" > ${SEAFILE_CENTRAL_CONF_DIR}/seahub_settings.py

		mkdir -p /seafile/data/seahub-data/avatars
		mv -f seafile-server/seahub/media/avatars/* /seafile/data/seahub-data/avatars/
		rm -rf seafile-server/seahub/media/avatars
		ln -s /seafile/data/seahub-data/avatars /seafile/seafile-server/seahub/media/avatars
		echo '* seahub configured successfully'
	fi

	python seafile-server/seahub/manage.py syncdb || exit 5
	echo '* seahub database synchronized successfully'

    chown -R seafile:seafile /seafile/
    chown -R seafile:seafile /tmp/seahub_cache

	# Keep seafile version for managing future updates
	echo -n "${SEAFILE_VERSION}" > data/$VERSION_FILE
	echo "Configuration compleated!"

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

			# Copy upgrade scripts. symlink doesn't work, unfortunatelly
			#  and I do not want to patch all of them
			cp -rf /usr/local/share/seafile/scripts/upgrade seafile-server/
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
				SCRIPT="./seafile-server/upgrade/upgrade_${i1p}.${i2p}_${i1}.${i2}.sh"
				if [ -f $SCRIPT ]; then
					echo "Executing $SCRIPT..."
                    echo | $SCRIPT

					i1p=$i1
					i2p=$i2
					i2=`expr "$i2" '+' 1`
				else
					i1p=$i1
					i1=`expr "$i1" '+' 1`
					i2=0
				fi
			done

			# Run minor upgrade, just in case (Actually needed when only last number was changed)
    		echo | ./seafile-server/upgrade/minor-upgrade.sh

			rm -rf seafile-server/upgrade

            chown -R seafile:seafile /seafile/

			echo -n "${SEAFILE_VERSION}" > data/$VERSION_FILE
		fi
	else
		echo "Version is the same, no upgrade needed"
	fi
fi

exec "$@"