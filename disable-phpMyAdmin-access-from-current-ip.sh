#/bin/bash

CURRENT_USER_IP=$(who am i|grep -Po '([0-9]{1,3}[\.]){3}[0-9]{1,3}')
ESCAPED_CURRENT_USER_IP=$(sed -E s/\\./\\\\./g <<< "$CURRENT_USER_IP")
echo "Disabling phpMyAdmin Access from your IP address: $CURRENT_USER_IP"
sed -E -i "s/(\s*)Require ip $ESCAPED_CURRENT_USER_IP//" /etc/httpd/conf.d/phpMyAdmin.conf
sed -E -i "s/(\s*)Allow from $ESCAPED_CURRENT_USER_IP//" /etc/httpd/conf.d/phpMyAdmin.conf
sed -E -i 's/\n\n/\n/' /etc/httpd/conf.d/phpMyAdmin.conf

systemctl restart httpd.service
