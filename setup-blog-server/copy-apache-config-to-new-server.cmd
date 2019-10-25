@echo off

@REM MODIFY THESE VARIABLE BEFORE YOU TRY TO USE THIS SCRIPT!!!!!

@REM These are the ssh keys you use to connect from  you local machine to the 
@REM remote servers. They must already be set up to allow you to connect with
@REM these keys. 
SET OLD_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key
SET NEW_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key
@REM A directory to use as a local staging dir to copy files to/from because we assume
@REM our old/new servers can't directly connect to each other because they are on different VPCs at Amazon. 
SET LOCAL_OUTPUT_DIRECTORY=%USERPROFILE%\tmp\example-blog\

@REM Old Blog Server Config
SET OLD_HOST=ec2-88-88-888-88.compute-1.amazonaws.com
SET OLD_HOST_APACHE_CONF_DIR=%USERPROFILE%\Documents\blog\server-config\qa\etc\httpd\
SET OLD_HOST_APACHE_CONF_FILE=conf\httpd.conf
SET OLD_HOST_APACHE_SSL_CONF_FILE=conf\httpd.conf
SET OLD_HOST_UPLOAD_DIR=/home/ec2-user/
SET OLD_HOST_USERNAME=ec2-user
SET OLD_HOST_SSL_CERT=old.example.blog.crt
SET OLD_HOST_SSL_KEY=old.example.blog.key

@REM New Blog Server Config
SET NEW_HOST_APACHE_CONF_DIR=/etc/httpd/
SET NEW_HOST_APACHE_CONF_FILE=conf/httpd.conf
SET NEW_HOST_APACHE_SSL_CONF_FILE=conf/httpd.conf
SET NEW_HOST_UPLOAD_DIR=/home/ec2-user/
SET NEW_HOST_USERNAME=ec2-user
SET NEW_HOST=ec2-99-999-999-99.compute-1.amazonaws.com
SET NEW_HOST_SSL_CERT=new.example.blog.crt
SET NEW_HOST_SSL_KEY=new.example.blog.key



echo "Starting transfer of cert..."

@REM copy old apache config to accessible dir so we can download them via scp
echo copying old cert and key to home directory
ssh -i %OLD_SERVER_PRIVATE_KEY% %OLD_HOST_USERNAME%@%OLD_HOST% "sudo cp %OLD_HOST_APACHE_CONF_DIR%/%OLD_HOST_APACHE_CONF_FILE% %OLD_HOST_UPLOAD_DIR%%OLD_HOST_APACHE_CONF_FILE%"
ssh -i %OLD_SERVER_PRIVATE_KEY% %OLD_HOST_USERNAME%@%OLD_HOST% "sudo cp %OLD_HOST_APACHE_CONF_DIR%/%OLD_HOST_APACHE_SSL_CONF_FILE% %OLD_HOST_UPLOAD_DIR%%OLD_HOST_APACHE_SSL_CONF_FILE%"


@REM secure copy apache config from old server while preserving modification/access/mode of original file...
echo copying old cert and key to local machine
scp -i %OLD_SERVER_PRIVATE_KEY% -p %OLD_HOST_USERNAME%@%OLD_HOST%:/home/ec2-user/%OLD_HOST_APACHE_CONF_FILE% "%LOCAL_OUTPUT_DIRECTORY%\%OLD_HOST_APACHE_CONF_FILE%"
scp -i %OLD_SERVER_PRIVATE_KEY% -p %OLD_HOST_USERNAME%@%OLD_HOST%:/home/ec2-user/%OLD_HOST_APACHE_SSL_CONF_FILE% "%LOCAL_OUTPUT_DIRECTORY%\%OLD_HOST_APACHE_SSL_CONF_FILE%"


@REM secure copy apache config to new  server while preserving modification/access/mode of original file...
echo copying old cert and key to new server home directory
scp -i %NEW_SERVER_PRIVATE_KEY% -p "%LOCAL_OUTPUT_DIRECTORY%\%NEW_HOST_SSL_CERT%" %NEW_HOST_USERNAME%@%NEW_HOST%:%NEW_HOST_UPLOAD_DIR%%NEW_HOST_APACHE_CONF_FILE%
scp -i %NEW_SERVER_PRIVATE_KEY% -p "%LOCAL_OUTPUT_DIRECTORY%\%NEW_HOST_SSL_KEY%" %NEW_HOST_USERNAME%@%NEW_HOST%:%NEW_HOST_UPLOAD_DIR%%NEW_HOST_APACHE_SSL_CONF_FILE%

@REM move apache config to final location
echo moving certs to final location on new server
ssh -i %NEW_SERVER_PRIVATE_KEY% %NEW_HOST_USERNAME%@%NEW_HOST% "sudo mv /home/ec2-user/%NEW_HOST_APACHE_CONF_FILE% %NEW_HOST_APACHE_CONF_DIR%/%NEW_HOST_APACHE_CONF_FILE%"
ssh -i %NEW_SERVER_PRIVATE_KEY% %NEW_HOST_USERNAME%@%NEW_HOST% "sudo mv /home/ec2-user/%NEW_HOST_APACHE_SSL_CONF_FILE% %NEW_HOST_APACHE_CONF_DIR%/%NEW_HOST_APACHE_SSL_CONF_FILE%"


