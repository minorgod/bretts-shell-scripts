@REM BE SURE TO SET THESE VARIABLES PROPERLY...
@echo on

SET OLD_HOST=%1
SET NEW_HOST=%2

if "%OLD_HOST%"=="" (
 	set "OLD_HOST=ec2-88-8-888-888.compute-1.amazonaws.com"
)

if "%NEW_HOST%"=="" (
 	set "NEW_HOST=ec2-99-99-99-999.us-east-2.compute.amazonaws.com"
)

if "%OLD_SERVER_PRIVATE_KEY%"=="" (
 	set "OLD_SERVER_PRIVATE_KEY=%3"
)

if "%NEW_SERVER_PRIVATE_KEY%"=="" (
 	set "NEW_SERVER_PRIVATE_KEY=%4"
)

if "%OLD_SERVER_PRIVATE_KEY%"=="" (
    @REM this can be either a private key file or a .pem file. 
 	set "OLD_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key"
)

if "%NEW_SERVER_PRIVATE_KEY%"=="" (
 	@REM this can be either a private key file or a .pem file. 
	set "NEW_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key"
)

SET MYSQL_DUMP_FILENAME=wordpress-db-dump.sql
SET LOCAL_OUTPUT_DIRECTORY=%USERPROFILE%\Documents\example-blog

@REM OLD HOST INFO
SET OLD_HOST_USERNAME=ec2-user
SET OLD_HOST_OUTPUT_DIR=/home/ec2-user
SET OLD_HOST_DATABASE_NAME=wordpress
SET OLD_HOST_MYSQL_USERNAME=wordpress-user
SET OLD_HOST_MYSQL_PASSWORD=youroldmysqlpassword

@REM NEW HOST INFO
SET NEW_HOST_USERNAME=ec2-user
SET NEW_HOST_OUTPUT_DIR=/home/ec2-user
SET NEW_HOST_DATABASE_NAME=wordpress
SET NEW_HOST_MYSQL_USERNAME=wordpress-user
SET NEW_HOST_MYSQL_PASSWORD=yournewmysqlpassword


@REM ssh into server and create dump file
echo "logging into old server and dumping database..."
ssh -i "%OLD_SERVER_PRIVATE_KEY%" %OLD_HOST_USERNAME%@%OLD_HOST% "mysqldump --host=localhost --user=%OLD_HOST_MYSQL_USERNAME% --password=%OLD_HOST_MYSQL_PASSWORD% %OLD_HOST_DATABASE_NAME% > %OLD_HOST_OUTPUT_DIR%/%MYSQL_DUMP_FILENAME%"

@REM secure copy from old server while preserving modification/access/mode of original file...
echo "Copying db dump to local machine..."
scp -i "%OLD_SERVER_PRIVATE_KEY%" -p %OLD_HOST_USERNAME%@%OLD_HOST%:%OLD_HOST_OUTPUT_DIR%/%MYSQL_DUMP_FILENAME% "%LOCAL_OUTPUT_DIRECTORY%\%MYSQL_DUMP_FILENAME%"

@REM secure copy to new  server while preserving modification/access/mode of original file...
echo "Copying db dump to new remote machine..."
scp -i "%NEW_SERVER_PRIVATE_KEY%" -p "%LOCAL_OUTPUT_DIRECTORY%\%MYSQL_DUMP_FILENAME%" %NEW_HOST_USERNAME%@%NEW_HOST%:%NEW_HOST_OUTPUT_DIR%/%MYSQL_DUMP_FILENAME%

@REM ssh into new server and load the dump file
echo "Loading db dump into database on new machine."
ssh -i "%NEW_SERVER_PRIVATE_KEY%" %NEW_HOST_USERNAME%@%NEW_HOST% "sudo mysqldump --user=root %NEW_HOST_DATABASE_NAME% < %NEW_HOST_OUTPUT_DIR%/%MYSQL_DUMP_FILENAME%"