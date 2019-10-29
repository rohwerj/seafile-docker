REPLACE INTO EmailUser(email, passwd, is_staff, is_active, ctime) VALUES ('%ADMIN_EMAIL%', sha1('%ADMIN_PASSWORD%'), 1, 1, 0);
