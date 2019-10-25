
#userful commands if you need to see all info about running processes:
#ps ax o pid,user,group,gid,%cpu,%mem,vsz,rss,tty,stat,start,time,comm
# Set up and EC2 instance using AMI: ami-0688148b3659c6d16
#become root
sudo su

#add these lines to /root/.bashrc
#alias ls='ls -alh'
#alias ps='ps ax o pid,user,group,gid,%cpu,%mem,vsz,rss,tty,stat,start,time,comm'
#then run
source ~/.bashrc

#install essential tools
sudo yum -y install wget nano unzip gcc gcc-c++

# install the latest EPEL repos so we don't have to use Oracle's ancient versions of GIT and other tools...
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

#install ius repository for the same reason...
wget -O enable-ius.sh https://setup.ius.io/
chmod 700 enable-ius.sh
./enable-ius.sh
yum repolist

#install a newer version of mariadb repository...
#Upgrade from MariaDB 5.6 to 10.0
sudo mysql -u root -Bse "SET GLOBAL innodb_fast_shutdown=0;quit;"
sudo service mariadb-server stop
sudo service mysql stop
sudo yum remove mariadb*
sudo curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
sudo sed -i 's/10.4/10.0/' /etc/yum.repos.d/mariadb.repo
sudo yum clean all

sudo yum install mariadb-server
sudo service mysql start
sudo mysql_upgrade
#Upgrade from MariaDB 10.0 to 10.1
sudo mysql -u root -Bse "SET GLOBAL innodb_fast_shutdown=0;quit;"
sudo service mysql stop
sudo yum remove MariaDB-*
sudo sed -i 's/10.4/10.1/' /etc/yum.repos.d/mariadb.repo
sudo yum clean all
sudo yum update

sudo yum install mariadb-server
sudo service mysql start
sudo mysql_upgrade

#Upgrade from MariaDB 10.1 to 10.2
sudo mysql -u root -Bse "SET GLOBAL innodb_fast_shutdown=0;quit;"
sudo service mysql stop
sudo yum -y remove MariaDB-*
sudo sed -i 's/10.1/10.2/' /etc/yum.repos.d/mariadb.repo
sudo yum -y update

sudo yum -y install mariadb-server
sudo service mysql start
sudo mysql_upgrade

#Upgrade from MariaDB 10.2 to 10.3
sudo mysql -u root -Bse "SET GLOBAL innodb_fast_shutdown=0;quit;"
sudo service mysql stop
sudo yum -y remove MariaDB-* galera-*
sudo sed -i 's/10.2/10.3/' /etc/yum.repos.d/mariadb.repo
sudo yum -y update

sudo yum -y install mariadb-server
sudo service mysql start
sudo mysql_upgrade

#Upgrade from MariaDB 10.3 to 10.4
sudo mysql -u root -Bse "SET GLOBAL innodb_fast_shutdown=0;quit;"
sudo service mysql stop
sudo yum -y remove MariaDB-* galera-*
sudo sed -i 's/10.3/10.4/' /etc/yum.repos.d/mariadb.repo
sudo yum -y update

sudo yum -y install mariadb-server
sudo service mariadb start
sudo mysql_upgrade


#update our packages
yum -y update

#enable replacing packages via yum-plugin-replace
yum -y install yum-plugin-replace



#install mariadb
yum -y install mariadb-server
#set mysql/mariadb to run on boot
chkconfig --level 35 mariadb on
service mariadb start
#if you cannot log into mysql as root by typing mysql -u root, run this to see if the root password in logged on firstrun...
echo $(grep -oP 'temporary password(.*): \K(\S+)' /var/log/mariadb/mariadb.log)
#if so, you can either remove the root password, or modify /etc/my.cnf and add it under the [client] section:
#[client]
#user = root
#password = xxxxxxxxx

#systemd config files will be in: 
# /etc/systemd/system/multi-user.target.wants/
#If, for some reason mysql/mariadb does not start, you may need to manually init the data dir and set mysql to be daemonized...
#/usr/libexec/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/


# Also, this is not applicable unless you're running mysql8 or higher, but...
# In MySQL 8.0, the default authentication plugin has changed from mysql_native_password 
# to caching_sha2_password, and the 'root'@'localhost' administrative account uses 
# caching_sha2_password by default. If you prefer that the root account use the previous 
# default authentication plugin (mysql_native_password), see caching_sha2_password and 
# the root Administrative Account...run this...
# sudo mysql -u root -Bse "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';"

#create wordpress database and user and grand priviliges...
sudo mysql -u root -Bse "
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE wordpress;
CREATE USER 'wordpress-user'@'%' IDENTIFIED BY 'consumer';
CREATE USER 'wordpress-user'@'localhost' IDENTIFIED BY 'consumer';
CREATE USER 'pma'@'localhost' IDENTIFIED BY 'password';
"

#create wordpress database and user and grand priviliges...
sudo mysql -u root -Bse '
USE mysql;
CREATE USER "wordpress-user"@"%" IDENTIFIED BY "***";GRANT USAGE ON *.* TO "wordpress-user"@"%" IDENTIFIED BY "***" REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON `wordpress`.* TO "wordpress-user"@"%" WITH GRANT OPTION;
CREATE USER "wordpress-user"@"localhost" IDENTIFIED BY "***";GRANT USAGE ON *.* TO "wordpress-user"@"localhost" IDENTIFIED BY "***" REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON `wordpress`.* TO "wordpress-user"@"localhost" WITH GRANT OPTION;
flush privileges;
quit
'


sudo mysql -u root -Bse "
use wordpress
GRANT ALL PRIVILEGES ON wordpress TO 'wordpress-user'@'%';
GRANT ALL PRIVILEGES ON wordpress TO 'wordpress-user'@'localhost';
GRANT ALL PRIVILEGES ON wordpress TO 'pma'@'localhost';
flush privileges;
quit
"

sudo mysql -u root -Bse "
use mysql;
update user set plugin='mysql_native_password' where user='wordpress-user';
flush privileges;
quit"

sudo mysql -u root -Bse "
use wordpress;
source /home/ec2-user/wordpress-db-dump.sql
quit"

sudo mysql -u root -Bse "
use phpmyadmin;
source /usr/share/phpMyAdmin/sql/create_tables.sql;
source /usr/share/phpMyAdmin/sql/create_tables_drizzle.sql;
quit"


#update php repository info:
sudo mv /etc/yum.repos.d/public-yum-ol7.repo /etc/yum.repos.d/public-yum-ol7.repo.bak
sudo wget -O /etc/yum.repos.d/public-yum-ol7.repo http://yum.oracle.com/public-yum-ol7.repo
sudo yum install -y yum-utils
sudo yum-config-manager --enable ol7_developer_php72
yum update

#don't bother trying to include xdebug in this install because nobody
#bothers to keep up with creating current binaries for Oracle linux. You'll
#have to install it from source or download a standalone binary and install yourself. 

	

service httpd start
chkconfig --level 35 httpd on

#add iptables rules
#clear all the rules
sudo iptables -F
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT
sudo service iptables save
sudo service iptables reload

# Open /etc/httpd/conf.d/phpMyAdmin.conf 
# and add "Require all granted" to the same blocks where it says Require ip 127.0.0.1
# just do this temporarily, or add your IP address only. 
# phpmyadmin is installed in /usr/share/phpMyAdmin

#install git from ius repos
yum -y install git2u

#set up the local git server
sudo adduser git
su git
cd
mkdir .ssh && chmod 700 .ssh
touch .ssh/authorized_keys && chmod 600 .ssh/authorized_keys
exit
#add the ec2-user's authorized keys to the git user's authorized_keys
sudo cat /home/ec2-user/.ssh/authorized_keys >> /home/git/.ssh/authorized_keys

mkdir /srv/git
git init --bare /srv/git/example-blog.git
chown -R git:git /srv/git/example-blog.git/

#now push your local repository to the remote server...

#IMPORTANT-- MAKE SURE YOU ARE NOT SU NOW -- execute these commands as ec2-user to prevent permission issues. 

#now on the remote server, clone the local repository to the folder it will be served from ....
git clone -v --progress file://git@/srv/git/example-blog.git /home/ec2-user/blog
cd blog
#on dev/qa server checkout develop branch. On prod checkout production branch.
git checkout develop

#install composer dependencies
composer install

#Install Nodejs/npm LTS version (via node version manager)
cd ~
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
source ~/.profile     ## Debian based systems 
source ~/.bashrc      ## CentOS/RHEL systems 
nvm install lts/*

#install gulp and bower globally 
npm i -g gulp bower

#build the frontend in the themes directory...
cd ~/blog/public_html/wp-content/themes/sage-8.4.2
npm install
bower install
gulp --production

#dump the old db on the old server -- assuming you are logged in in a different ssh session...
scp -i "%USERPROFILE%\Documents\Confidential Files\ssh_keys\example_blog\qa\example-blog-qa-keypair.pem" -p ec2-user@ec2-999-9-999-99.compute-1.amazonaws.com:/home/ec2-user/wordpress-db-dump.sql "%USERPROFILE%\Documents\blog\wordpress-db-dump.sql"
 
#now upload it to the new remote server
scp -i "%USERPROFILE%\Documents\Confidential Files\ssh_keys\example_blog\qa\example-blog-qa-keypair.pem" -p "%USERPROFILE%\Documents\blog\wordpress-db-dump.sql" ec2-user@ec2-3-84-29-80.compute-1.amazonaws.com:/home/ec2-user/wordpress-db-dump.sql
 
#load the dump file
mysqldump --host=localhost --user=wordpress-user --password=consumer wordpress < ~/wordpress-db-dump.sql



#chown ec2-user dir to 755
#add ec2-user to apache group
sudo usermod -a -G apache ec2-user
sudo find . -exec chown myuser:a-common-group-name {} +
sudo find . -type f -exec chmod 664 {} +
sudo find . -type d -exec chmod 775 {} +
sudo chmod 660 public_html/wp-config.php








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

