
#userful commands:
ps ax o pid,user,group,gid,%cpu,%mem,vsz,rss,tty,stat,start,time,comm

#mysql prerequisites for RHEL7 style linux distros
sudo dnf install libaio
sudo dnf install ncurses-compat-libs


#https://computingforgeeks.com/how-to-install-mysql-8-on-fedora/
sudo dnf -y install https://repo.mysql.com//mysql80-community-release-fc29-2.noarch.rpm
sudo dnf --disablerepo=mysql80-community --enablerepo=mysql57-community install mysql-community-server
#https://dev.mysql.com/doc/refman/8.0/en/binary-installation.html#binary-installation-layout
groupadd mysql
useradd -r -g mysql -s /bin/false mysql
mysqld --initialize --user=mysql
mysql_ssl_rsa_setup
mysqld &

password=$(grep -oP 'temporary password(.*): \K(\S+)' /var/log/mysqld.log)
mysqladmin --user=root --password="$password" password aaBB@@cc1122
mysql --user=root --password=aaBB@@cc1122 -e "UNINSTALL PLUGIN validate_password;"
mysqladmin --user=root --password="aaBB@@cc1122" password ""

#change owenrship of php-fpm socket dir
touch /run/php-fpm/www.sock
chmod 660 /run/php-fpm/www.sock
chown -R apache:apache /run/php-fpm
#edit php-fpm config - comment out acl line
nano /etc/php-fpm.d/www.conf
#start php-fpm
/usr/sbin/php-fpm

/sbin/httpd -k restart

sudo yum install epel-release
sudo yum install nano
# install the LAMP stack
sudo yum install nano \
  httpd httpd-devel \
  mariadb-server \
  php-fpm \
  php-cli \
  php-common \
  php-devel \
  php-curl \
  php-opcache \
  php-xml \
  php-bz2 \
  php-intl \
  php-xdebug \
  php-mysqlnd \
  php-odbc \
  php-mbstring \
  php-gd \
  php-zip
  
  
#enable apache2 rewrite module
#sudo a2enmod rewrite
#sudo a2enmod headers

#install phpmyadmin
sudo yum install phpmyadmin
#choose the defaults and use "password" for the password

#enable phpmyadmin
sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin
sudo /sbin/httpd -k restart
#sudo service apache2 reload

#set up mysql -- change password plugin
mysqld -u root --skip-grant-tables
sudo mysql -u root -Bse "
use mysql;
#allow non-local mysql passwordless login from root
update user set plugin='mysql_native_password' where user='root';
flush privileges;
#to re-enable local only root login change plugin back to unix_socket

#create the wordpress db and user
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE wordpress;
CREATE USER 'wordpress-user'@'%' IDENTIFIED BY 'consumer';
GRANT ALL PRIVILEGES ON wordpress TO 'wordpress-user'@'%';
flush privileges;
quit;"

