#!/bin/bash
source ./easyoptions.sh || exit


## example Blog Setup Script v1.0
##
## This program does something. Usage:
##     @#script.name [option]
##
## Options:
##     -h, --help              All client scripts have this by default,
##                             it shows this double-hash documentation.
##         -o, --option            This option will get stored as option=yes.
##                             Long version is mandatory, and can be
##                             specified before or after short version.
##
##         --some-boolean      This will get stored as some_boolean=yes.
##
##         --old-host=VALUE  This will get stored as some_value=VALUE,
##                             where VALUE is the actual value specified.
##                             The equal sign is optional and can be
##                             replaced with blank space. Short version
##                             is not available in this format.
##         --new-host=VALUE  This will get stored as some_value=VALUE,
##                             where VALUE is the actual value specified.
##                             The equal sign is optional and can be
##                             replaced with blank space. Short version
##                             is not available in this format.

# Boolean and parameter options
[[ -n "$some_option"  ]] && echo "Option specified: --some-option"
[[ -n "$some_boolean" ]] && echo "Option specified: --some-boolean"
[[ -n "$some_value"   ]] && echo "Option specified: --some-value is $some_value"
[[ -n "$old_host"   ]] && echo "Option specified: --old-host is $old_host"

# Arguments
for argument in "${arguments[@]}"; do
    echo "Argument specified: $argument"
done

if [ -z "$old_host" ]; then
        echo "You must provide the --old-host param, eg: --old-host=ec2-88-8-888-88.compute-1.amazonaws.com"
        exit
fi

if [ -z "$new_host" ]; then
        PUBLIC_HOSTNAME=$new_host
else
        PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
fi

OLD_HOST=$old_host
#This url is the amazon ec2 instance metadata service...do not modify the ip address,
#it has nothing to do with the ip address of your server, we're simply calling the
#service here to find out the public ip address and hostname of this EC2 instance.
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
WEB_SERVER_USER='apache'
WEB_SERVER_GROUP='apache'
WEB_USER_NAME='ec2-user'
WEB_USER_GROUP='ec2-user'
GIT_USER_NAME='git'
GIT_USER_GROUP='ec2-user'
BLOG_REPOSITORY_NAME='example-blog.git'

#stop mysql before we begin
sudo service mysqld stop

#install essential tools
sudo yum -y install wget nano unzip gcc gcc-c++

#install the oracle php release repository...
sudo yum -y install oracle-php-release-el7

#install latest EPEL repos
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install ius repository to allow latest versions of git and some other tools
sudo wget -O enable-ius.sh https://setup.ius.io/
sudo chmod 700 enable-ius.sh
sudo ./enable-ius.sh

#install the mysql community repository from the oracle linux yum server
sudo yum -y install mysql-release-el7

#disable mariadb, mysql, apache and php in ius repositories
sudo sed -i 's/^enabled = 1/enabled = 1\nexclude = mariadb* mysql* httpd* apache* php*/' /etc/yum.repos.d/ius.repo
#disable mariadb in oracle-linux-ol7 repositories
sudo sed -i 's/^enabled=1/enabled=1\nexclude=mariadb*/' /etc/yum.repos.d/oracle-linux-ol7.repo

#Enable the ius repository for latest stable git release
sudo yum-config-manager --enable ius
#disable Oracle Linux mysql8 and enable Oracle Linux mysql5.7 repositories
sudo yum-config-manager --disable ol7_MySQL80
sudo yum-config-manager --enable ol7_MySQL57
#enable the Oracle Linux php 7.2 repository.
sudo yum-config-manager --enable ol7_developer_php72

#Update our packages
sudo yum clean all
sudo yum -y update

#list our repositories
sudo yum repolist all

# Enable replacing packages via yum-plugin-replace
# yum -y install yum-plugin-replace

# ==================================================
# BEGIN SET UP FIREWALL
# ==================================================

# generate an iptables script, save it and run it to set the firewall rules...
sudo cat > /root/firewall.sh << EOF
#!/bin/bash

#save this file to /root/firewall.sh
#then run: chmod u+x /root/firewall.sh
#then run this file to set up iptables rules.

# Set the default policies to allow everything while we set up new rules.
# Prevents cutting yourself off when running from remote SSH.
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Flush any existing rules, leaving just the defaults
iptables -F

# Open port 21 for incoming FTP requests...no thanks.
#iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# Open port 22 for incoming SSH connections.
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# Limit to eth0 from a specific IP subnet if required.
#iptables -A INPUT -i eth0 -p tcp -s 192.168.122.0/24 --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

# Open port 80 for incoming HTTP requests.
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
# Open port 443 for incoming HTTPS requests. (uncomment if required)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# *** Put any additions to the INPUT chain here.
#
# *** End of additions to INPUT chain.

# Accept any localhost (loopback) calls.
iptables -A INPUT -i lo -j ACCEPT

# Allow any existing connection to remain.
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Reset the default policies to stop all incoming and forward requests.
iptables -P INPUT DROP
iptables -P FORWARD DROP
# Accept any outbound requests from this server.
iptables -P OUTPUT ACCEPT

# Save the settings.
service iptables save
# Use the following command in Fedora
#iptables-save > /etc/sysconfig/iptables

# Display the settings.
iptables -L -v --line-numbers
EOF

sudo chmod u+x /root/firewall.sh
sudo /root/firewall.sh

# ==================================================
# END SET UP FIREWALL
# ==================================================

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

# UPDATE mysql.user SET authentication_string=PASSWORD('somecrazylongrandompassword') WHERE User='root';
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


#/bin/bash
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

# Set up SSL cert
sudo cat > /etc/pki/tls/certs/example.com-02072017.crt << EOF
-----BEGIN CERTIFICATE-----
paste your cert here or fix this script so it copies a cert from somewhere else!!!
-----END CERTIFICATE-----
EOF

# Set up SSL private key
sudo cat > /etc/pki/tls/private/example.com-02072017.key << EOF
-----BEGIN PRIVATE KEY-----
paste your key here or fix this script so it copies a key from somewhere else!!!
-----END PRIVATE KEY-----
EOF


#tweak some php settings...
sudo sed -i 's/^post_max_size = 8M/post_max_size = 200M/' /etc/php.ini
sudo sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php.ini
sudo sed -i 's/^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_STRICT/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/' /etc/php.ini

# ==================================================
# END SET UP APACHE AND PHP
# ==================================================




# ==================================================
# BEGIN SET UP PHPMYADMIN
# ==================================================

# find the current logged in user's ip address to add it to the allowed users apache config...
CURRENT_USER_IP=$(who am i|grep -Po "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
echo "$CURRENT_USER_IP"
# Now replace the phpMyAdmin.conf file with a version that includes a blog to enable your
# current remote user to log in. If you need to log in from a different location you will
# need to add that as well.

sudo cat > /etc/httpd/conf.d/phpMyAdmin.conf << EOF

# phpMyAdmin - Web based MySQL browser written in php
#
# Allows only localhost by default
#
# But allowing phpMyAdmin to anyone other than localhost should be considered
# dangerous unless properly secured by SSL

Alias /phpMyAdmin /usr/share/phpMyAdmin
Alias /phpmyadmin /usr/share/phpMyAdmin

<Directory /usr/share/phpMyAdmin/>
   AddDefaultCharset UTF-8

   <IfModule mod_authz_core.c>
     # Apache 2.4
     <RequireAny>
       Require ip 127.0.0.1
       Require ip ::1
	   Require ip $CURRENT_USER_IP
     </RequireAny>
   </IfModule>
   <IfModule !mod_authz_core.c>
     # Apache 2.2
     Order Deny,Allow
     Deny from All
     Allow from 127.0.0.1
     Allow from ::1
	 Allow from $CURRENT_USER_IP
   </IfModule>
</Directory>

<Directory /usr/share/phpMyAdmin/setup/>
   <IfModule mod_authz_core.c>
     # Apache 2.4
     <RequireAny>
       Require ip 127.0.0.1
       Require ip ::1
	   Require ip $CURRENT_USER_IP
     </RequireAny>
   </IfModule>
   <IfModule !mod_authz_core.c>
     # Apache 2.2
     Order Deny,Allow
     Deny from All
     Allow from 127.0.0.1
     Allow from ::1
	 Allow from $CURRENT_USER_IP
   </IfModule>
</Directory>

# These directories do not require access over HTTP - taken from the original
# phpMyAdmin upstream tarball
#
<Directory /usr/share/phpMyAdmin/libraries/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>

<Directory /usr/share/phpMyAdmin/setup/lib/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>

<Directory /usr/share/phpMyAdmin/setup/frames/>
    Order Deny,Allow
    Deny from All
    Allow from None
</Directory>

# This configuration prevents mod_security at phpMyAdmin directories from
# filtering SQL etc.  This may break your mod_security implementation.
#
#<IfModule mod_security.c>
#    <Directory /usr/share/phpMyAdmin/>
#        SecRuleInheritance Off
#    </Directory>
#</IfModule>
EOF

sudo cat /etc/httpd/conf.d/phpMyAdmin.conf

#now replace the phpMyAdmin config file with a version that allows root login and allows your IP address...
PMA_USER_PASSWORD=$(sudo openssl rand -base64 32)
echo "pma user password: $PMA_USER_PASSWORD"
sudo cat > phpMyAdmin_install_script.sql << EOF
#create a phpmyadmin database...
CREATE DATABASE IF NOT EXISTS phpmyadmin;
#give read only access to db and user tables in mysql database
CREATE USER IF NOT EXISTS "pma"@"%" IDENTIFIED BY "$PMA_USER_PASSWORD";
CREATE USER IF NOT EXISTS "pma"@"localhost" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT SELECT ON mysql.db TO "pma"@"%" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT SELECT ON mysql.db TO "pma"@"localhost" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT SELECT ON mysql.user TO "pma"@"%" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT SELECT ON mysql.user TO "pma"@"localhost" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT ALL PRIVILEGES ON phpmyadmin.* TO "pma"@"%" IDENTIFIED BY "$PMA_USER_PASSWORD";
GRANT ALL PRIVILEGES ON phpmyadmin.* TO "pma"@"localhost" IDENTIFIED BY "$PMA_USER_PASSWORD";
FLUSH PRIVILEGES;
EOF

#execute the secure install script...
sudo mysql -uroot <phpMyAdmin_install_script.sql

#generate random blowfish secret....
BLOWFISH_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

sudo cat > /etc/phpMyAdmin/config.inc.php  << EOF

<?php
/**
 * phpMyAdmin configuration file, you can use it as base for the manual
 * configuration. For easier setup you can use "setup/".
 *
 * All directives are explained in Documentation.html and on phpMyAdmin
 * wiki <http://wiki.phpmyadmin.net>.
 */

/*
 * This is needed for cookie based authentication to encrypt password in
 * cookie
 */
\$cfg['blowfish_secret'] = '$BLOWFISH_SECRET'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */

/**
 * Server(s) configuration
 */
\$i = 0;

// The \$cfg['Servers'] array starts with \$cfg['Servers'][1].  Do not use
// \$cfg['Servers'][0]. You can disable a server config entry by setting host
// to ''. If you want more than one server, just copy following section
// (including \$i incrementation) serveral times. There is no need to define
// full server array, just define values you need to change.
\$i++;
\$cfg['Servers'][\$i]['host']          = 'localhost'; // MySQL hostname or IP address
\$cfg['Servers'][\$i]['port']          = '';          // MySQL port - leave blank for default port
\$cfg['Servers'][\$i]['socket']        = '';          // Path to the socket - leave blank for default socket
\$cfg['Servers'][\$i]['connect_type']  = 'tcp';       // How to connect to MySQL server ('tcp' or 'socket')
\$cfg['Servers'][\$i]['extension']     = 'mysqli';    // The php MySQL extension to use ('mysql' or 'mysqli')
\$cfg['Servers'][\$i]['compress']      = FALSE;       // Use compressed protocol for the MySQL connection
                                                    // (requires PHP >= 4.3.0)
\$cfg['Servers'][\$i]['controluser']   = 'pma';          // MySQL control user settings
                                                    // (this user must have read-only
\$cfg['Servers'][\$i]['controlpass']   = '$PMA_USER_PASSWORD';          // access to the "mysql/user"
                                                    // and "mysql/db" tables).
                                                    // The controluser is also
                                                    // used for all relational
                                                    // features (pmadb)
\$cfg['Servers'][\$i]['auth_type']     = 'cookie';    // Authentication method (config, http or cookie based)?
\$cfg['Servers'][\$i]['user']          = '';          // MySQL user
\$cfg['Servers'][\$i]['password']      = '';          // MySQL password (only needed
                                                    // with 'config' auth_type)
\$cfg['Servers'][\$i]['only_db']       = '';          // If set to a db-name, only
                                                    // this db is displayed in left frame
                                                    // It may also be an array of db-names, where sorting order is relevant.
\$cfg['Servers'][\$i]['hide_db']       = '';          // Database name to be hidden from listings
\$cfg['Servers'][\$i]['verbose']       = '';          // Verbose name for this host - leave blank to show the hostname

\$cfg['Servers'][\$i]['pmadb']         = 'phpmyadmin';          // Database used for Relation, Bookmark and PDF Features
                                                    // (see scripts/create_tables.sql)
                                                    //   - leave blank for no support
                                                    //     DEFAULT: 'phpmyadmin'
\$cfg['Servers'][\$i]['bookmarktable'] = '';          // Bookmark table
                                                    //   - leave blank for no bookmark support
                                                    //     DEFAULT: 'pma_bookmark'
\$cfg['Servers'][\$i]['relation']      = '';          // table to describe the relation between links (see doc)
                                                    //   - leave blank for no relation-links support
                                                    //     DEFAULT: 'pma_relation'
\$cfg['Servers'][\$i]['table_info']    = '';          // table to describe the display fields
                                                    //   - leave blank for no display fields support
                                                    //     DEFAULT: 'pma_table_info'
\$cfg['Servers'][\$i]['table_coords']  = '';          // table to describe the tables position for the PDF schema
                                                    //   - leave blank for no PDF schema support
                                                    //     DEFAULT: 'pma_table_coords'
\$cfg['Servers'][\$i]['pdf_pages']     = '';          // table to describe pages of relationpdf
                                                    //   - leave blank if you don't want to use this
                                                    //     DEFAULT: 'pma_pdf_pages'
\$cfg['Servers'][\$i]['column_info']   = '';          // table to store column information
                                                    //   - leave blank for no column comments/mime types
                                                    //     DEFAULT: 'pma_column_info'
\$cfg['Servers'][\$i]['history']       = '';          // table to store SQL history
                                                    //   - leave blank for no SQL query history
                                                    //     DEFAULT: 'pma_history'
\$cfg['Servers'][\$i]['verbose_check'] = TRUE;        // set to FALSE if you know that your pma_* tables
                                                    // are up to date. This prevents compatibility
                                                    // checks and thereby increases performance.
\$cfg['Servers'][\$i]['AllowRoot']     = TRUE;        // whether to allow root login
\$cfg['Servers'][\$i]['AllowDeny']['order']           // Host authentication order, leave blank to not use
                                     = '';
\$cfg['Servers'][\$i]['AllowDeny']['rules']           // Host authentication rules, leave blank for defaults
                                     = array();
\$cfg['Servers'][\$i]['AllowNoPassword']              // Allow logins without a password. Do not change the FALSE
                                     = FALSE;       // default unless you're running a passwordless MySQL server
\$cfg['Servers'][\$i]['designer_coords']              // Leave blank (default) for no Designer support, otherwise
                                     = '';          // set to suggested 'pma_designer_coords' if really needed
\$cfg['Servers'][\$i]['bs_garbage_threshold']         // Blobstreaming: Recommented default value from upstream
                                     = 50;          //   DEFAULT: '50'
\$cfg['Servers'][\$i]['bs_repository_threshold']      // Blobstreaming: Recommented default value from upstream
                                     = '32M';       //   DEFAULT: '32M'
\$cfg['Servers'][\$i]['bs_temp_blob_timeout']         // Blobstreaming: Recommented default value from upstream
                                     = 600;         //   DEFAULT: '600'
\$cfg['Servers'][\$i]['bs_temp_log_threshold']        // Blobstreaming: Recommented default value from upstream
                                     = '32M';       //   DEFAULT: '32M'
/*
 * End of servers configuration
 */

/*
 * Directories for saving/loading files from server
 */
\$cfg['UploadDir'] = '/var/lib/phpMyAdmin/upload';
\$cfg['SaveDir']   = '/var/lib/phpMyAdmin/save';

/*
 * Disable the default warning that is displayed on the DB Details Structure
 * page if any of the required Tables for the relation features is not found
 */
\$cfg['PmaNoRelation_DisableWarning'] = TRUE;

/*
 * phpMyAdmin 4.4.x is no longer maintained by upstream, but security fixes
 * are still backported by downstream.
 */
\$cfg['VersionCheck'] = FALSE;
?>
EOF

sudo cat /etc/phpMyAdmin/config.inc.php
sudo chmod 644 /etc/phpMyAdmin/config.inc.php
sudo chmod 644 /etc/httpd/conf.d/phpMyAdmin.conf

#create phpmyadmin tables...
sudo mysql -uroot </usr/share/phpMyAdmin/sql/create_tables.sql

# ==================================================
# END SET UP PHPMYADMIN
# ==================================================
