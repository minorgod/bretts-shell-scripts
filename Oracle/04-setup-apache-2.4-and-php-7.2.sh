#!/bin/bash

# ==================================================
# BEGIN SET UP APACHE AND PHP
# ==================================================

#This url is the amazon ec2 instance metadata service...do not modify the ip address,
#it has nothing to do with the ip address of your server, we're simply calling the
#service here to find out the public ip address and hostname of this EC2 instance.
PUBLIC_HOSTNAME=$(sudo curl http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(sudo curl http://169.254.169.254/latest/meta-data/public-ipv4)


#now install all the other server software such as apache, php.
sudo yum -y install httpd \
	mod_ssl \
	php \
	php-cli \
	php-common \
	php-devel \
	php-curl \
	php-opcache \
	php-xml \
	php-bz2 \
	php-intl \
	php-mysqlnd \
	php-odbc \
	php-mbstring \
	php-gd \
	php-zip \
	phpmyadmin \
	composer

#start apache and configure it to run on boot
sudo service httpd start
sudo chkconfig --level 35 httpd on


echo "Verify that you can now view apache default page in your browser...open the url for this ec2 server:"
echo "http://$PUBLIC_HOSTNAME"
read -p "Then hit [ENTER] to continue."


# Verify that PHP is working...
# php -i
sudo cat > /var/www/html/phpinfo.php << EOF
<?php phpinfo();
EOF

echo "Open the phpinfo.php page in your browser..."
echo "if php is working with apache you should see a nice info page:"
echo "http://$PUBLIC_HOSTNAME/phpinfo.php"
read -p "Then hit [ENTER] to continue."
sudo rm -f /var/www/html/phpinfo.php

# Set up SSL cert -- you should replace the cert with your own, or just manually copy them to your server
# and don't forget to set up the cert and keys in your ssl vhost config. 

# sudo cat > /etc/pki/tls/certs/your-cert-name.crt << EOF
# -----BEGIN CERTIFICATE-----
# You will need to put your own cert here dummy! You may have
# multiple sections that say  begin/end cert, that is fine. 
# -----END CERTIFICATE-----
# EOF

# # Set up SSL private key
# sudo cat > /etc/pki/tls/private/your-private-key-name.key << EOF
# -----BEGIN PRIVATE KEY-----
# You will need to put your own private key here dummy! 
# -----END PRIVATE KEY-----
# EOF


#tweak some php settings...you might not want this, but it makes it easier to upload a large sql dump in phpMyAdmin. 
sudo sed -i 's/^post_max_size = 8M/post_max_size = 200M/' /etc/php.ini
sudo sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php.ini
sudo sed -i 's/^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_STRICT/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/' /etc/php.ini

# ==================================================
# END SET UP APACHE AND PHP
# ==================================================