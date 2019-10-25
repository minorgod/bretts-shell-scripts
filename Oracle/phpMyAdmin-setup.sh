#!/bin/bash

# ==================================================
#  This script assumes you have already set up 
#  mysql and apache2 using the other scripts found
#  in this repository. It assumes you are allowing
#  root login and that you will be locking down remote
#  access to phpMyAdmin via your Apache2 config. 
#  There are a couple of scripts in this repository
#  to do that for you automatically. 
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
\$cfg['blowfish_secret'] = 'WURQ4GYbjKtCLevK4spNrHNyL7BQk59j'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */

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
