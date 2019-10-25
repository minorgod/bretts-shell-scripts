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
PUBLIC_HOSTNAME=$(sudo curl -s http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(sudo curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
WEB_SERVER_USER='apache'
WEB_SERVER_GROUP='apache'
WEB_USER_NAME='ec2-user'
WEB_USER_GROUP='ec2-user'
GIT_USER_NAME='git'
GIT_USER_GROUP='ec2-user'
WORDPRESS_DB_NAME='wordpress'
WORDPRESS_DB_USER='wordpress-user'
BLOG_REPOSITORY_NAME='example-blog.git'
BLOG_DIR=/home/$WEB_USER_NAME/example-blog

# ==================================================
# BEGIN SET UP WORDPRESS
# ==================================================
#set up git
sudo yum -y install git2u
sudo adduser git

#move into git home dir
#cd
#set up ssh access for git
#mkdir .ssh && chmod 700 .ssh
sudo mkdir /home/$GIT_USER_NAME/.ssh
sudo touch /home/$GIT_USER_NAME/.ssh/authorized_keys
sudo chmod 700 /home/$GIT_USER_NAME/.ssh
sudo chmod 600 /home/$GIT_USER_NAME/.ssh/authorized_keys
sudo chown -R $GIT_USER_NAME:$GIT_USER_GROUP /home/$GIT_USER_NAME/.ssh
#copy ec2-user's authorized keys to git user's authorized keys...
sudo cat /home/$WEB_USER_NAME/.ssh/authorized_keys >> /home/$GIT_USER_NAME/.ssh/authorized_keys

sudo mkdir /srv/git
sudo git init --bare /srv/git/$BLOG_REPOSITORY_NAME
sudo chown -R $GIT_USER_NAME:$GIT_USER_GROUP /srv/git/$BLOG_REPOSITORY_NAME/

#set up git post-recieve hook
sudo touch /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive
sudo chmod 755 /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive

sudo cat > /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive <<EOF

#!/bin/sh
#
# /srv/git/$BLOG_REPOSITORY_NAME/hooks/post-receive
#

#IMPORTANT!!!
#SET THE BRANCH TO 'develop' in QA or DEV and 'production' in PROD environments
BRANCH="develop"
SITE_NAME="example Blog (QA)"
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
sudo chown $GIT_USER_NAME:$GIT_USER_GROUP /srv/git/example-blog.git/hooks/post-receive

WORDPRESS_USER_PASSWORD=$(sudo openssl rand -base64 32)

sudo cat > wordpress_db_setup.sql << EOF
CREATE DATABASE IF NOT EXISTS $WORDPRESS_DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE $WORDPRESS_DB_NAME;
CREATE USER IF NOT EXISTS "$WORDPRESS_DB_USER"@"%" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
CREATE USER IF NOT EXISTS "$WORDPRESS_DB_USER"@"localhost" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
CREATE USER  IF NOT EXISTS "$WORDPRESS_DB_USER"@"127.0.0.1" IDENTIFIED BY "$WORDPRESS_USER_PASSWORD";
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'%' WITH GRANT OPTION;
flush privileges;
use mysql;
update user set plugin="mysql_native_password" where user="$WORDPRESS_DB_USER";
flush privileges;
quit
EOF

#execute the wordpress db script...
sudo mysql -uroot <wordpress_db_setup.sql

sudo cat > wordpress_user_password_update.sql << EOF
USE $WORDPRESS_DB_NAME;
UPDATE mysql.user SET authentication_string=PASSWORD('$WORDPRESS_USER_PASSWORD') WHERE User="$WORDPRESS_DB_USER";
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'127.0.0.1' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wordpress.* TO '$WORDPRESS_DB_USER'@'%' WITH GRANT OPTION;
flush privileges;
quit
EOF


#execute the wordpress user passwoerd update script...
sudo mysql -uroot <wordpress_user_password_update.sql

#add the user that will own the web files to the apache group:
sudo usermod -a -G $WEB_SERVER_USER $WEB_USER_GROUP
#add the git user to the web server group so it can write to the checked out example-blog dir.
sudo usermod -a -G $GIT_USER_NAME $WEB_USER_GROUP
sudo usermod -a -G $GIT_USER_NAME $WEB_SERVER_GROUP

echo "To complete the wordpress setup, push the develop branch of the example-blog repository to"
echo "git@$PUBLIC_HOSTNAME:/srv/git/$BLOG_REPOSITORY_NAME"
read -p "Once you do that, press [Enter] key to continue."



#sudo su ec2-user


#git clone -v --progress file://git@/srv/git/$BLOG_REPOSITORY_NAME /home/ec2-user/example-blog
sudo git clone -v --progress file://git@/srv/git/$BLOG_REPOSITORY_NAME /home/$WEB_USER_NAME/example-blog
sudo chown -R $WEB_USER_NAME:$WEB_SERVER_GROUP blog
cd example-blog

#Set owner and permissions on the wordpress files...
sudo git checkout develop
sudo chown -R $WEB_USER_NAME:$WEB_SERVER_GROUP blog

sudo find $BLOG_DIR -exec chown $WEB_USER_NAME:$WEB_SERVER_GROUP {} +
sudo chmod -R 750 $BLOG_DIR
sudo find $BLOG_DIR -type f -exec chmod 660 {} +
#sudo find . -type d -exec chmod 775 {} +
sudo chmod 660 $BLOG_DIR/public_html/wp-config.php
#make the uploads folder group writable...
sudo chmod -R g+w $BLOG_DIR/public_html/wp-content/uploads



#copy apache config file for current environment to config dir...
sudo cp $BLOG_DIR/server-config/qa/etc/httpd/conf.d/example.com.conf /etc/httpd/conf.d/example.com.conf
#update the ServerName 52.6.114.18:443 variable with the new server's ip address:
PUBLIC_IP=$(sudo curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sudo sed -E -i "s/(\s*)(ServerName\s*\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/\1ServerName $PUBLIC_IP/" /etc/httpd/conf.d/example.com.conf

#restart apache
sudo service httpd restart

#generate the .env file
sudo touch $BLOG_DIR/.env
sudo chown -R $WEB_USER_NAME:$WEB_SERVER_GROUP $BLOG_DIR/.env
sudo cat > $BLOG_DIR/.env <<EOF
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

#install composer dependencies without su (as $WEB_USER_NAME)
composer install


#Install Nodejs/npm LTS version (via node version manager)
cd /home/$WEB_USER_NAME/
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
source ~/.profile     # Debian based systems
source ~/.bashrc     # CentOS/RHEL systems

export NVM_DIR="/home/$WEB_USER_NAME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


nvm install lts/*

#install gulp and bower globally
npm i -g gulp bower

#build the frontend in the themes directory...
cd $BLOG_DIR/public_html/wp-content/themes/sage-8.4.2
npm install
bower install
gulp --production


#install wordpress-cli tool
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
#check the Phar file to verify that it’s working:
php wp-cli.phar --info
#Make the file executable and move it to somewhere in your PATH. For example:
chmod +x wp-cli.phar
mv wp-cli.phar /usr/bin/wp

#Now, deactivate the security plugins on the new server if they aren't already...
#they can be re-enabled after the blog is up and running and they
#will reconfigure themselves for the new server.
wp plugin list --path=$BLOG_DIR/public_html
wp plugin deactivate all-in-one-wp-security-and-firewall --path=$BLOG_DIR/public_html
wp plugin deactivate wordfence --path=$BLOG_DIR/public_html/

#PUBLIC_HOSTNAME="ec2-54-234-253-55.compute-1.amazonaws.com"
wp search-replace --path=$BLOG_DIR/public_html 'www.example.com' $PUBLIC_HOSTNAME
wp search-replace --path=$BLOG_DIR/public_html 'example.com' $PUBLIC_HOSTNAME

#Now change the ownership of any files that were messed up by the build process...
sudo find $BLOG_DIR -exec chown $WEB_USER_NAME:$WEB_SERVER_GROUP {} +
sudo chmod -R 750 $BLOG_DIR
sudo find $BLOG_DIR -type f -exec chmod 660 {} +
#sudo find . -type d -exec chmod 775 {} +
sudo chmod 660 $BLOG_DIR/public_html/wp-config.php
#make the uploads folder group writable...
sudo chmod -R g+w $BLOG_DIR/public_html/wp-content/uploads

echo "Now run the following cmd scripts on your local pc:"
echo "copy-old-db-to-new-server.cmd $OLD_HOST $PUBLIC_HOSTNAME"
echo "copy-images-to-new-server.cmd $OLD_HOST $PUBLIC_HOSTNAME"
read -p "Once you do that, press [Enter] key to continue."

# ==================================================
# END SET UP WORDPRESS
# ==================================================

MYSQL_ROOT_PASSWORD=$(sudo grep -oP 'password=\K(\S+)' /root/.my.cnf)
echo "$MYSQL_ROOT_PASSWORD"

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
password $MYSQL_ROOT_PASSWORD
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
https://$PUBLIC_HOSTNAME/example-blog/wp-admin
\e[0m

When you are sure it's working, you should re-enable the security plugins either via
the wordpress admin web page, or via these commands:
\e[32m
wp plugin activate all-in-one-wp-security-and-firewall --path=\$HOME/example-blog/public_html/
wp plugin activate wordfence --path=\$HOME/example-blog/public_html/
\e[0m
EOF

echo -e "$INSTALL_INFO_MESSAGE"
