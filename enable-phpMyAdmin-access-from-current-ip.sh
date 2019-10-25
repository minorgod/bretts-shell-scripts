#/bin/bash

CURRENT_USER_IP=$(who am i|grep -Po '([0-9]{1,3}[\.]){3}[0-9]{1,3}')
echo "Enabling phpMyAdmin Access from your IP address: $CURRENT_USER_IP"
sed -E -i "s/(\s*)(Require ip 127\.0\.0\.1)/\1\2\n\1Require ip $CURRENT_USER_IP/" /etc/httpd/conf.d/phpMyAdmin.conf
sed -E -i "s/(\s*)(Allow from 127\.0\.0\.1)/\1\2\n\1Allow from $CURRENT_USER_IP/" /etc/httpd/conf.d/phpMyAdmin.conf


systemctl restart httpd.service