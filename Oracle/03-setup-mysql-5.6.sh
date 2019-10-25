#!/bin/bash

# ==================================================
# BEGIN SET UP MYSQL
# ==================================================


#Ensure that mysql and mariadb are completely uninstalled...
sudo yum -y remove mysql mysql-server mysql-community-* mariadb* MariaDB*
#remove all data and configs...
sudo rm -rf /var/lib/mysql
sudo rm -f /etc/my.cnf
sudo rm -f /root/.my.cnf
sudo rm -rf /var/log/mysql
sudo rm -rf /etc/my.cnf.d
sudo rm -rf /var/log/mariadb
sudo rm -rf /var/log/mysqld.log
sudo rm -rf /var/log/mysql.log
sudo rm -f /var/log/mariadb/mariadb.log.rpmsave
sudo rm -rf /var/lib/mysql
sudo rm -rf /usr/lib64/mysql
sudo rm -rf /usr/share/mysql

# Now install mysql 5.7 community server
sudo yum -y install mysql-community-server
sudo service mysqld start

#look for the MYSQL_ROOT_PASSWORD IN /root/.my.cnf
MYSQL_ROOT_PASSWORD=$(sudo grep -oP 'password=\K(\S+)' /root/.my.cnf)

# UPDATE mysql.user SET authentication_string=PASSWORD('8/lxlFk843cwI2sEPcdd9rQJIFiZ4kVAe0jT6Qke3Bw=') WHERE User='root';
# FLUSH PRIVILEGES;
# quit;

#If we can't find the root password file,
#it means we probably haven't installed mysql at all yet, so lets set it up like it's brand new
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
	#find the auto-generated mysql root password
	MYSQL_ROOT_PASSWORD=$(sudo grep -oP 'temporary password(.*): \K(\S+)' /var/log/mysqld.log)
	echo "MySQL root password:" "$MYSQL_ROOT_PASSWORD"

	if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
		#find the auto-generated mysql root password
		sudo MYSQL_ROOT_PASSWORD=$(sudo grep -oP 'temporary password(.*): \K(\S+)' /var/log/mysql.log)
		echo "MySQL root password:" "$MYSQL_ROOT_PASSWORD"
	fi

	#generate a new random password for use in mysql_secure_installation script...
	MYSQL_ROOT_PASSWORD_NEW=$(sudo openssl rand -base64 32)
	echo "NEW MySQL root password:" "$MYSQL_ROOT_PASSWORD_NEW"


	#the above method doesn't work, so let's do it the easy way directly via an sql script...
	# mysql_secure_installation.sql
	sudo cat > mysql_secure_installation.sql << EOF
# Reset password using alter statement first becuase it has an expired password by default..
SET PASSWORD = PASSWORD('$MYSQL_ROOT_PASSWORD_NEW');
# Make sure that NOBODY can access the server without a password
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASSWORD_NEW') WHERE User='root';
# Kill the anonymous users
DELETE FROM mysql.user WHERE User='';
# disallow remote login for root
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
# Kill off the demo database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
# Make our changes take effect
FLUSH PRIVILEGES;
EOF

	#execute the secure install script...
	sudo mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --connect-expired-password <mysql_secure_installation.sql
	#now remove the script
	sudo rm -f mysql_secure_installation.sql

	#now set up mysql client so local commandline connections from root user do not need a root password.
	sudo cat > ~/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD_NEW
EOF

	#lock down that config file.
	sudo chmod 400 ~/.my.cnf

	#now unset the mysql vars in our commandline since we shouldn't need them anymore
	#MYSQL_ROOT_PASSWORD=
	#MYSQL_ROOT_PASSWORD_NEW=

	#set mysql to start on boot
	sudo chkconfig --level 35 mysqld on

fi



# ==================================================
# END SET UP MYSQL
# ==================================================