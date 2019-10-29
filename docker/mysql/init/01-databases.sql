# create databases
CREATE DATABASE IF NOT EXISTS `ccnet`;
CREATE DATABASE IF NOT EXISTS `seafile`;
CREATE DATABASE IF NOT EXISTS `seahub`;

# create seafile user and grant rights
CREATE USER 'seafile'@'%' IDENTIFIED BY 'seafile';
GRANT ALL ON *.* TO 'seafile'@'%';
