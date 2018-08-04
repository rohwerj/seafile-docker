# Seafile Server Docker image
[Seafile](http://seafile.com/) server Docker image based on [Alpine Linux](https://hub.docker.com/_/alpine/).
Based on the image from sunx/seafile-docker(https://github.com/VGoshev/seafile-docker).

## Supported tags and respective `Dockerfile` links

* [`6.2.5`](https://github.com/rohwerj/seafile-docker/blob/6.2.5/docker/Dockerfile), [`latest`](https://github.com/rohwerj/seafile-docker/blob/master/docker/Dockerfile) - Seafile Server v6.2.5 - latest available version

## Quickstart

To run container you can use following command:
```bash
docker run \  
  -v seafile_data:/seafile/datat \
  -p 127.0.0.1:8000:8000 \  
  -p 127.0.0.1:8082:8082 \  
  rohwerj/seafile`
```
Containers, based on this image, will automatically configure
 a Seafile enviroment if it doesn't already exist. If the existing Seafile enviroment is from a previous version of Seafile, container will automatically upgrade it to latest version (by calling the Seafile database upgrade scripts).
 
A backup of the databases and data volume should be made before an upgrade to a newer version.

## Detailed description of image and containers

### Used ports

This image uses 2 tcp ports:
* 8000 - seafile port
* 8082 - seahub port

If you want to run seafdav (WebDAV for Seafile), then port 8080 will be used also (not currently supported by this image).

### Volume
This image uses one volume with internal path `/seafile/data`

I would recommend you use host directory mapping of named volume to run containers, so you will not lose your valuable data after image update and starting a new container

### Web server configuration

This image doesnt contain any web-servers, because you, usually, already have some http server running on your server and don't want to run any extra http-servers (because it will cost you some CPU time and Memory). But if you know some really tiny web-server with proxying support, tell me and I would be glad to integrate it to the image.


For Web-server configuration, as media directory location you should enter
`/seafile/seafile-server/seahub/media`

In [httpd-conf](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/) directory you can find
[lighttpd](https://www.lighttpd.net/) [config example](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/lighttpd.conf.example) and
[haaproxy](https://www.haproxy.com/) [config example](https://github.com/rohwerj/seafile-docker/blob/master/httpd-conf/haproxy.cfg).

You can find 
[Nginx](https://manual.seafile.com/deploy/deploy_with_nginx.html) and 
[Apache](https://manual.seafile.com/deploy/deploy_with_apache.html) 
configurations in official Seafile Server [Manual](https://manual.seafile.com/).

### Supported ENV variables

When you running container, you can pass several enviroment variables (with **--env** option of **docker run** command):
* **`SERVER_NAME`**=\<...> - Name of Seafile server (3 - 15 letters or digits), used only for first run. Default: Seafile
* **`SERVER_DOMAIN`**=\<...> - Domain or ip of seafile server, used only for first run. Default: seafile.domain.com
* **`MYSQL_HOST`**=\<...> - Host name of mysql/mariadb server. Used for waiting on the database server on startup (not used if empty). Default: <empty>
* **`MYSQL_USER`**=\<...> - User name for the mysql/mariadb server. Only used when MYSQL_HOST is set. Default: seafile
* **`MYSQL_PASS`**=\<...> - Password for the mysql/mariadb server. Only used when MYSQL_HOST is set. Default: seafile

## Useful commands in container

With `docker exec -it seafile ash` the following commands can be executed:
* `seaf-fsck -F /seafile/data/conf -c /seafile/data/ccnet -d /seafile/data/seafile-data` check your libraries for errors
* `seafserv-gc -F /seafile/data/conf -c /seafile/data/ccnet -d /seafile/data/seafile-data ` - remove ald unused data from storage of your seafile libraries

## Tips&amp;Tricks and Known issues

* Make sure, that mounted data volume and files are radable and writable by container's seafile user(2016:2016).

* If you want to run seafdav, which is disabled by default, you can read it's [manual](https://manual.seafile.com/extension/webdav.html). Do not forget to publish port 8080 after it.
(not yet supported by this image).

* If you do not want container to automatically upgrade your Seafile enviroment on image (and Seafile-server) update, 
you can add empty file named `.no-update` to directory `/seafile/data` in your container. You can use **`docker exec <container_name> touch /seafile/data/.no-update`** for it.

* Container uses seafile user to run seafile, so if you need to do something with root access in container, you can use **`docker exec -ti --user=0 <container_name> /bin/sh`** for it.

* This image configures a sqlite-based Seafile server installation. The plan is to support the mysql installation in a later version.

## License

This Dockerfile and scripts are released under [MIT License](https://github.com/rohwerj/seafile-docker/blob/master/LICENSE).

[Seafile](https://github.com/haiwen/seafile/blob/master/LICENSE.txt) and [Alpine Linux](https://www.alpinelinux.org/) have their own licenses.
