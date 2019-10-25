#!/bin/bash
source ./easyoptions.sh || exit


## Setup a LAMP stack with a Wordpress Blog on Oracle Linux from Scratch v1.0
##
## This attempts to set up a new blog server and transfer everything from
## the old host to the new host. Usage:
##     @#setup-blog-server.sh --old-host=your.oldhost.com --new-host=you.newhost.com
##
## Options:
##     -h, --help              All client scripts have this by default,
##                             it shows this double-hash documentation.
##         -o, --option            This option will get stored as option=yes.
##                             Long version is mandatory, and can be
##                             specified before or after short version.
##
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
#[[ -n "$some_option"  ]] && echo "Option specified: --some-option"
#[[ -n "$some_boolean" ]] && echo "Option specified: --some-boolean"
#[[ -n "$some_value"   ]] && echo "Option specified: --some-value is $some_value"
#[[ -n "$old_host"   ]] && echo "Option specified: --old-host is $old_host"

# Arguments
for argument in "${arguments[@]}"; do
    echo "Argument specified: $argument"
done

if [ -z "$old_host" ]; then
        echo "You must provide the --old-host param, eg: --old-host=ec2-12-3-456-78.compute-1.amazonaws.com"
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
#service here to find out the public ip address and hostname of the EC2 instance this script is running on. 
PUBLIC_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
WEB_SERVER_USER='apache'
WEB_SERVER_GROUP='apache'
WEB_USER_NAME='ec2-user'
WEB_USER_GROUP='ec2-user'
GIT_USER_NAME='git'
GIT_USER_GROUP='ec2-user'
BLOG_REPOSITORY_NAME='your-blog-repository-name.git'

#stop mysql before we begin
service mysqld stop

#install essential tools
yum -y install wget nano unzip gcc gcc-c++

#install the oracle php release repository...
yum -y install oracle-php-release-el7

#install latest EPEL repos
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install ius repository to allow latest versions of git and some other tools
wget -O enable-ius.sh https://setup.ius.io/
chmod 700 enable-ius.sh
./enable-ius.sh

#install the mysql community repository from the oracle linux yum server
yum -y install mysql-release-el7

#disable mariadb, mysql, apache and php in ius repositories
sed -i 's/^enabled = 1/enabled = 1\nexclude = mariadb* mysql* httpd* apache* php*/' /etc/yum.repos.d/ius.repo
#disable mariadb in oracle-linux-ol7 repositories
sed -i 's/^enabled=1/enabled=1\nexclude=mariadb*/' /etc/yum.repos.d/oracle-linux-ol7.repo

#Enable the ius repository for latest stable git release
yum-config-manager --enable ius
#disable Oracle Linux mysql8 and enable Oracle Linux mysql5.7 repositories
yum-config-manager --disable ol7_MySQL80
yum-config-manager --enable ol7_MySQL57
#enable the Oracle Linux php 7.2 repository. 
yum-config-manager --enable ol7_developer_php72

#Update our packages
#yum clean all
yum -y update

#list our repositories
yum repolist all

# Enable replacing packages via yum-plugin-replace
# yum -y install yum-plugin-replace

# ==================================================
# BEGIN SET UP FIREWALL
# ==================================================

# generate an iptables script, save it and run it to set the firewall rules...
cat > /root/firewall.sh << EOF
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

chmod u+x /root/firewall.sh
/root/firewall.sh

# ==================================================
# END SET UP FIREWALL
# ==================================================

# ==================================================
# BEGIN SET UP MYSQL
# ==================================================


#Ensure that mysql and mariadb are completely uninstalled...
yum -y remove mysql mysql-server mysql-community-* mariadb* MariaDB*
#remove all data and configs...
rm -rf /var/lib/mysql
rm -f /etc/my.cnf
rm -f /root/.my.cnf
rm -rf /var/log/mysql
rm -rf /etc/my.cnf.d
rm -rf /var/log/mariadb
rm -rf /var/log/mysqld.log
rm -rf /var/log/mysql.log
rm -f /var/log/mariadb/mariadb.log.rpmsave
rm -rf /var/lib/mysql
rm -rf /usr/lib64/mysql
rm -rf /usr/share/mysql

# Now install mysql 5.7 community server
yum -y install mysql-community-server
service mysqld start

#look for the MYSQL_ROOT_PASSWORD IN /root/.my.cnf
MYSQL_ROOT_PASSWORD=$(grep -oP 'password=\K(\S+)' /root/.my.cnf)

# UPDATE mysql.user SET authentication_string=PASSWORD('8/lxlFk843cwI2sEPcdd9rQJIFiZ4kVAe0jT6Qke3Bw=') WHERE User='root';
# FLUSH PRIVILEGES;
# quit;

#If we can't find the root password file, 
#it means we probably haven't installed mysql at all yet, so lets set it up like it's brand new
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
	#find the auto-generated mysql root password
	MYSQL_ROOT_PASSWORD=$(grep -oP 'temporary password(.*): \K(\S+)' /var/log/mysqld.log)
	echo "MySQL root password:" "$MYSQL_ROOT_PASSWORD" 
	
	if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
		#find the auto-generated mysql root password
		MYSQL_ROOT_PASSWORD=$(grep -oP 'temporary password(.*): \K(\S+)' /var/log/mysql.log)
		echo "MySQL root password:" "$MYSQL_ROOT_PASSWORD" 
	fi
	
	#generate a new random password for use in mysql_secure_installation script...
	MYSQL_ROOT_PASSWORD_NEW=$(openssl rand -base64 32)
	echo "NEW MySQL root password:" "$MYSQL_ROOT_PASSWORD_NEW" 
	

	#the above method doesn't work, so let's do it the easy way directly via an sql script...
	# mysql_secure_installation.sql
	cat > mysql_secure_installation.sql << EOF
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
	mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --connect-expired-password <mysql_secure_installation.sql
	#now remove the script
	rm -f mysql_secure_installation.sql

	#now set up mysql client so local commandline connections from root user do not need a root password. 
	cat > ~/.my.cnf << EOF
[client]
user=root
password=$MYSQL_ROOT_PASSWORD_NEW
EOF

	#lock down that config file.
	chmod 400 ~/.my.cnf

	#now unset the mysql vars in our commandline since we shouldn't need them anymore
	#MYSQL_ROOT_PASSWORD=
	#MYSQL_ROOT_PASSWORD_NEW=

	#set mysql to start on boot
	chkconfig --level 35 mysqld on

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
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)


#now install all the other server software such as apache, php.
yum -y install httpd \
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
	phpmyadmin

#start apache and configure it to run on boot
service httpd start
chkconfig --level 35 httpd on


echo "Verify that you can now view apache default page in your browser...open the url for this ec2 server:"
echo "http://$PUBLIC_HOSTNAME"
read -p "Then hit [ENTER] to continue."


# Verify that PHP is working...
# php -i
cat > /var/www/html/phpinfo.php << EOF
<?php phpinfo();

EOF

echo "Open the phpinfo.php page in your browser..." 
echo "if php is working with apache you should see a nice info page:"
echo "http://$PUBLIC_HOSTNAME/phpinfo.php"
read -p "Then hit [ENTER] to continue."
rm -f /var/www/html/phpinfo.php

# Set up SSL cert
cat > /etc/pki/tls/certs/www.example.com.crt << EOF
-----BEGIN CERTIFICATE-----
paste your own damned cert here, or better yet fix this script to copy it from an external file somehere else!
-----END CERTIFICATE-----

EOF

# Set up SSL private key
cat > /etc/pki/tls/private/www.example.com.key << EOF
-----BEGIN PRIVATE KEY-----
paste your own damned private key here, or better yet fix this script to copy it from an external file somehere else!
-----END PRIVATE KEY-----
EOF


#tweak some php settings...
sed -i 's/^post_max_size = 8M/post_max_size = 200M/' /etc/php.ini
sed -i 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/' /etc/php.ini
sed -i 's/^error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT & ~E_STRICT/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/' /etc/php.ini

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

cat > /etc/httpd/conf.d/phpMyAdmin.conf << EOF

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

cat /etc/httpd/conf.d/phpMyAdmin.conf

#now replace the phpMyAdmin config file with a version that allows root login and allows your IP address...
PMA_USER_PASSWORD=$(openssl rand -base64 32)
echo "pma user password: $PMA_USER_PASSWORD"
cat > phpMyAdmin_install_script.sql << EOF
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
mysql -uroot <phpMyAdmin_install_script.sql

#generate random blowfish secret....
BLOWFISH_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

cat > /etc/phpMyAdmin/config.inc.php  << EOF

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

cat /etc/phpMyAdmin/config.inc.php
chmod 644 /etc/phpMyAdmin/config.inc.php
chmod 644 /etc/httpd/conf.d/phpMyAdmin.conf

#create phpmyadmin tables...
mysql -uroot </usr/share/phpMyAdmin/sql/create_tables.sql

# ==================================================
# END SET UP PHPMYADMIN 
# ==================================================


# ==================================================
# BEGIN SET UP WORDPRESS 
# WITH DEPLOYMENT VIA LOCAL GIT REPOSITORY
# ==================================================

#set up git
yum -y install git2u
adduser git

#move into git home dir
#cd
#set up ssh access for git
#mkdir .ssh && chmod 700 .ssh
su -c "mkdir /home/$GIT_USER_NAME/.ssh && chmod 700 /home/$GIT_USER_NAME/.ssh" $GIT_USER_NAME
su -c "touch /home/$GIT_USER_NAME/.ssh/authorized_keys && chmod 600 /home/$GIT_USER_NAME/.ssh/authorized_keys" $GIT_USER_NAME
chown -R $GIT_USER_NAME:$GIT_USER_GROUP /home/$GIT_USER_NAME/.ssh
#copy ec2-user's authorized keys to git user's authorized keys...
cat /home/$WEB_USER_NAME/.ssh/authorized_keys >> /home/$GIT_USER_NAME/.ssh/authorized_keys

mkdir /srv/git
git init --bare /srv/git/$BLOG_REPOSITORY_NAME
chown -R $GIT_USER_NAME:$GIT_USER_GROUP /srv/git/$BLOG_REPOSITORY_NAME/

#set up git post-recieve hook
touch /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive
chmod 755 /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive

cat /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive <<EOF

#!/bin/sh
#
# /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive
#

#IMPORTANT!!!
#SET THE BRANCH TO 'develop' in QA or DEV and 'production' in PROD environments
BRANCH="develop"
SITE_NAME="Your Blog Name Here Blog (QA)"
#IMPORTANT: Make sure this path matches the root directory of the live site
# NOT the public_html directory, but the parent directory of that dir!!!
SITE_PATH="/home/ec2-user/example-blog"

echo "**** \$SITE_NAME [post-receive] hook received."

while read oldrev newrev ref
do
  branch_received=`echo \$ref | cut -d/ -f3`

  echo "**** Received [\$branch_received] branch."

  # Making sure we received the branch we want.
  if [ \$branch_received = \$BRANCH ]; then
    cd \$SITE_PATH

    # Unset to use current working directory.
    unset GIT_DIR

    echo "**** Pulling changes."
    git pull origin \$BRANCH

    # Instead of pulling we can also do a checkout.
    #: '
    #echo "**** Checking out branch."
    #GIT_WORK_TREE=\$SITE_PATH git checkout -f \$BRANCH
    #'

    # Or we can also do a fetch and reset.
    #: '
    #echo "**** Fetching and reseting."
    #git fetch --all
    #git reset --hard origin/\$BRANCH
    #'

  else
    echo "**** Invalid branch, aborting."
    #exit 0

  fi
done

# [Restart/reload webserver stuff here]

echo "**** Done."

exec git-update-server-info

EOF

#change the owner post-receive hook 
chown git:git /srv/git/example-blog.git/hooks/post-receive

WORDPRESS_USER_PASSWORD=$(openssl rand -base64 32)

cat > wordpress_db_setup.sql << EOF
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE wordpress;
CREATE USER IF NOT EXISTS "wordpress-user"@"%" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
CREATE USER IF NOT EXISTS "wordpress-user"@"localhost" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
CREATE USER  IF NOT EXISTS "wordpress-user"@"127.0.0.1" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
GRANT ALL PRIVILEGES ON wordpress TO "wordpress-user"@"%";
GRANT ALL PRIVILEGES ON wordpress TO "wordpress-user"@"localhost";
GRANT ALL PRIVILEGES ON wordpress TO "wordpress-user"@"127.0.0.1";
flush privileges;
use mysql;
update user set plugin="mysql_native_password" where user="wordpress-user";
flush privileges;
quit
EOF

#execute the wordpress db script...
mysql -uroot <wordpress_db_setup.sql


#add the user that will own the web files to the apache group:
usermod -a -G $WEB_SERVER_USER $WEB_USER_GROUP


echo "To complete the wordpress setup, push the develop branch of the blog repository to"
echo "git@$PUBLIC_HOSTNAME:/srv/git/$BLOG_REPOSITORY_NAME"
read -p "Once you do that, press [Enter] key to continue."

echo "Now run the following cmd scripts on your local pc to copy the old wp db and images."
echo "The data/images will be copied to your local machine first, then to the new remote machine."
echo "Be sure to edit the scripts first to use your hostnames and private keys or they won't work!!!!"
echo "copy-old-db-to-new-server.cmd $OLD_HOST $PUBLIC_HOSTNAME"
echo "copy-images-to-new-server.cmd $OLD_HOST $PUBLIC_HOSTNAME"
read -p "Once you do that, press [Enter] key to continue."

#sudo su ec2-user

BLOG_DIR=/home/$WEB_USER_NAME/example-blog

#git clone -v --progress file://git@/srv/git/$BLOG_REPOSITORY_NAME /home/ec2-user/example-blog
su -c "git clone -v --progress file://git@/srv/git/$BLOG_REPOSITORY_NAME /home/$WEB_USER_NAME/example-blog" $WEB_USER_NAME
cd blog

#Set owner and permissions on the wordpress files...
su -c "git checkout develop" $WEB_USER_NAME

find $BLOG_DIR -exec chown $WEB_USER_NAME:$WEB_SERVER_GROUP {} +
chmod -R 750 $BLOG_DIR
find $BLOG_DIR -type f -exec chmod 660 {} +
#sudo find . -type d -exec chmod 775 {} +
chmod 660 $BLOG_DIR/public_html/wp-config.php
#make the uploads folder group writable...
chmod -R g+w $BLOG_DIR/public_html/wp-content/uploads



#copy apache config file for current environment (eg: qa) to config dir...
cp $BLOG_DIR/server-config/qa/etc/httpd/conf.d/example.com.conf /etc/httpd/conf.d/example.com.conf
#update the ServerName in IP v4 format (eg: 111.111.111.111:443) with the new server's ip address:
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sed -E -i "s/(\s*)(ServerName\s*\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/\1ServerName $PUBLIC_IP/" /etc/httpd/conf.d/example.com.conf

#generate the .env file
su -c "touch $BLOG_DIR/.env" $WEB_USER_NAME
cat $BLOG_DIR/.env <<EOF
WP_DEBUG=true

#This is the environment file format used by roots/bedrock (https://github.com/roots/bedrock)
DB_NAME=wordpress
DB_USER=wordpress-user
DB_PASSWORD=$WORDPRESS_USER_PASSWORD

# Optional variables
DB_HOST=localhost
DB_PREFIX=qxjzr_

WP_ENV=local
WP_HOME=https://local.example.com
WP_SITEURL=\${WP_HOME}/example-blog
EOF

#install composer
yum install composer

#install composer dependencies
su -c "composer install" $WEB_USER_NAME


#Install Nodejs/npm LTS version (via node version manager)
cd /home/$WEB_USER_NAME/
su -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash" $WEB_USER_NAME
su -c "source ~/.profile" $WEB_USER_NAME     # Debian based systems
su -c "source ~/.bashrc" $WEB_USER_NAME      # CentOS/RHEL systems 
 
export NVM_DIR="/home/$WEB_USER_NAME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


su -c "nvm install lts/*" $WEB_USER_NAME

#install gulp and bower globally 
su -c "npm i -g gulp bower" $WEB_USER_NAME

#build the frontend in the themes directory...yes, we're using an old version of sage from roots.io, which means we're also
#still using gulp/bower...yuck!
cd $BLOG_DIR/public_html/wp-content/themes/sage-8.4.2
su -c "npm install" $WEB_USER_NAME 
su -c "bower install --allow-root" $WEB_USER_NAME 
su -c "gulp --production" $WEB_USER_NAME 

#install wordpress-cli tool
su -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" $WEB_USER_NAME 
#check the Phar file to verify that it’s working:
su -c "php wp-cli.phar --info" $WEB_USER_NAME 
#Make the file executable and move it to somewhere in your PATH. For example:
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

#Now, deactivate the security plugins on the new server if they aren't already...
#they can be re-enabled after the blog is up and running and they 
#will reconfigure themselves for the new server. 
su -c "wp plugin list --path=$HOME/example-blog/public_html/" $WEB_USER_NAME 
su -c "wp plugin deactivate all-in-one-wp-security-and-firewall --path=$HOME/example-blog/public_html/" $WEB_USER_NAME 
su -c "wp plugin deactivate wordfence --path=$HOME/example-blog/public_html/" $WEB_USER_NAME 

#replace the old hostname with the new hostname.
su -c "wp search-replace --path=$HOME/example-blog/public_html 'www.example.com' $PUBLIC_HOSTNAME" $WEB_USER_NAME 
su -c "wp search-replace --path=$HOME/example-blog/public_html 'example.com' $PUBLIC_HOSTNAME" $WEB_USER_NAME 

# ==================================================
# END SET UP WORDPRESS 
# ==================================================

read -r -d '' INSTALL_INFO_MESSAGE << EOF
\e[1m

To complete the wordpress setup, push the develop branch of the blog repository to
git@$PUBLIC_HOSTNAME:/srv/git/example-blog.git

=======================================================================================
\e[32m                                 phpMyAdmin Access Info \e[0m
=======================================================================================
\e[0m
\e[32m
url: https://your-host-name/phpmyadmin
user: root
password $MYSQL_ROOT_PASSWORD_NEW
\e[0m

phpMyAdmin access has been enabled FOR YOUR CURRENT IP ONLY: $CURRENT_USER_IP
To enable/disable access from another IP, log in via ssh from that IP address
and run the following shell scripts as root...

enable-phpMyAdmin-access-from-current-ip.sh
disable-phpMyAdmin-access-from-current-ip.sh

If you need to set up a new wordpress admin user, run this command now:
\e[32mwp user create newusername newuser@somedomain.com --path=\$HOME/example-blog/public_html --role=administrator --user_pass=newuserpassword --display_name="New User"
\e[0m

You can now log into the blog at:
\e[32m
https://ec2-88-888-888-85.compute-1.amazonaws.com/example-blog/wp-admin
\e[0m

When you are sure it's working, you should re-enable the security plugins either via
the wordpress admin web page, or via these commands:
\e[32m
wp plugin activate all-in-one-wp-security-and-firewall --path=\$HOME/example-blog/public_html/
wp plugin activate wordfence --path=\$HOME/example-blog/public_html/
\e[0m
EOF

echo -e "$INSTALL_INFO_MESSAGE"
