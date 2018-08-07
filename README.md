# Seafile Server Docker image
[Seafile](http://seafile.com/) server Docker image based on [Alpine Linux](https://hub.docker.com/_/alpine/).
Based on the image from sunx/seafile-docker(https://github.com/VGoshev/seafile-docker).
Uses tini as PID 1 and supervisord as process manager.

## Supported tags and respective `Dockerfile` links

* [`6.2.5`](https://github.com/rohwerj/seafile-docker/blob/6.2.5/docker/Dockerfile), [`latest`](https://github.com/rohwerj/seafile-docker/blob/master/docker/Dockerfile) - Seafile Server v6.2.5 - latest available version

## Quickstart

To run container you can use following command:
```bash
docker run \  
  -v seafile_data:/seafile/data \
  -p 8000:8000 \
  -p 8082:8082 \
  rohwerj/seafile`
```
Containers, based on this image, will automatically configure
 a Seafile enviroment if it doesn't already exist. If the existing Seafile enviroment is from a previous version of Seafile, container will automatically upgrade it to latest version (by calling the Seafile database upgrade scripts).

A backup of the databases and data volume should be made before an upgrade to a newer version.

After update to version 6.3.x the following commands have to be executed in the running container:
`source /etc/profile.d/seafile.sh`
`python manage.py migrate_file_comment`
[see changelog](https://manual.seafile.com/changelog/server-changelog.html)

## Detailed description of image and containers

### Used ports

This image uses 3 tcp ports:
* 8000 - seafile port
* 8082 - seahub port
* 8080 - seafdav port (if enabled)

### Volume
This image uses one volume with internal path `/seafile/data`

The directory structure is the following:
/seafile -> main directory for the application
  /data  -> data directory with configuration and sqlite databases (if not using mysql)
  /seafile-server -> current version of the seafile-server
    /seahub       -> seahub application
  /logs   -> directory for all the log files
  /pids   -> directory containing the pid files

### Supported ENV variables

You can pass several enviroment variables to the image:
* **`SERVER_NAME`**=\<...> - Name of Seafile server (3 - 15 letters or digits), used only for the initialization. Default: Seafile
* **`SERVER_DOMAIN`**=\<...> - Domain or ip of seafile server, used only for the initialization. Default: seafile.domain.com
* **`MYSQL_HOST`**=\<...> - Host name of mysql/mariadb server. Used for waiting on the database server on startup (not used if empty) and initialization. Default: <empty>
* **`MYSQL_USER`**=\<...> - User name for the mysql/mariadb server. Only used when MYSQL_HOST is set. Default: seafile
* **`MYSQL_PASS`**=\<...> - Password for the mysql/mariadb server. Only used when MYSQL_HOST is set. Default: seafile
* **`ENABLE_SEAFDAV`**=\<...> - Can the true or false to indicate whether seafdav should be started. Default: false

## Initialization

On the first start with an empty volume mounted on /seafile/data, the image will initialize the seafile environment for you.
It uses the environment variable MYSQL_HOST to determine whether a sqlite or mysql setup is performed (variable ist empty -> sqlite, otherwise -> mysql).

To create a superuser you have to execute the following commands in the directory /seafile/seafile-server/seahub as user seafile:
`source /etc/profile.d/seafile.sh`
`python manage.py createsuperuser`

## Useful commands in container

With `docker exec --user=2016 -it seafile ash` the following commands can be executed:
* `seaf-fsck -F /seafile/data/conf -c /seafile/data/ccnet -d /seafile/data/seafile-data` check your libraries for errors
* `seafserv-gc -F /seafile/data/conf -c /seafile/data/ccnet -d /seafile/data/seafile-data ` - remove ald unused data from storage of your seafile libraries

### Web server configuration

This image does not contain any web-servers, but can be used behind one.

The media directory is located under
`/seafile/seafile-server/seahub/media`

In the directory [httpd-conf](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/) are example configurations for the following servers
[lighttpd](https://www.lighttpd.net/) [config example](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/lighttpd.conf.example) and
[haaproxy](https://www.haproxy.com/) [config example](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/haproxy.cfg).

Configuration examples are also available for
[Nginx](https://manual.seafile.com/deploy/deploy_with_nginx.html) and
[Apache](https://manual.seafile.com/deploy/deploy_with_apache.html)
in the official Seafile Server [Manual](https://manual.seafile.com/).

## Tips&amp;Tricks and Known issues

* Make sure, that mounted data volume and files are radable and writable by container's seafile user(2016:2016).

* If you do not want to automatically upgrade your Seafile enviroment,
you can add an empty file named `.no-update` to the directory `/seafile/data` in your container. You can use **`docker exec <container_name> touch /seafile/data/.no-update`** for it.

* The container uses the root user to start the entrypoint (and therefore supervisor). To execute scripts you need to use the seafile user **`docker exec -ti --user=2016 <container_name> /bin/sh`**.

## License

This Dockerfile and scripts are released under [MIT License](https://github.com/rohwerj/seafile-docker/blob/master/LICENSE).

[Seafile](https://github.com/haiwen/seafile/blob/master/LICENSE.txt) and [Alpine Linux](https://www.alpinelinux.org/) have their own licenses.
