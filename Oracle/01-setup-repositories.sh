#!/bin/bash

# Becuase Oracle Linux 7.2 installs MySQL 8 or MariaDB 10.x, which have compatiblity issues 
# with all kinds of current configurations, and there's not much reason to use MySQL 5.7 over 5.6,
# and because Oracle 7.2's version of GIT is ancient, and because their PHP7.2 is actually fairly up 
# to date....
# This script configures yum so it will install 
# --- MySQL 5.6 from the offical MySQL community repository,
# --- PHP7.2 from the Oracle repository
# --- The latest version of GIT from the ius repository
# 
# It also installs a few other useful tools that most ppl (me) are likely to want (need):
# -- wget nano unzip gcc gcc-c++

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