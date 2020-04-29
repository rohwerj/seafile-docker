FROM seafileltd/seafile-mc:7.0.5

MAINTAINER Jan Rohwer <jan@rohwer.online>

RUN sed -i "s/db_user = 'root'/db_user = get_conf('DB_USER', 'root')/g" /scripts/utils/__init__.py &&\
    sed -i "s/db_passwd = get_conf('DB_ROOT_PASSWD', '')/db_passwd = get_conf('DB_PASSWD', '')/g" /scripts/utils/__init__.py &&\
    sed -i "s/proxy_set_header Host $host;/proxy_set_header Host $http_host;/g" /etc/nginx/sites-enabled/seafile.conf
