CREATE TABLE IF NOT EXISTS EmailUser
  (id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT, email VARCHAR(255), passwd VARCHAR(256), is_staff BOOL NOT NULL, is_active BOOL NOT NULL, ctime BIGINT, reference_id VARCHAR(255), UNIQUE INDEX (email), UNIQUE INDEX(reference_id)) ENGINE=INNODB;

REPLACE INTO EmailUser(email, passwd, is_staff, is_active, ctime) VALUES ('%ADMIN_EMAIL%', sha1('%ADMIN_PASSWORD%'), 1, 1, 0);
