@echo off
SET OLD_HOST=%1
SET NEW_HOST=%2
@REM SET OLD_SERVER_PRIVATE_KEY=%3
@REM SET NEW_SERVER_PRIVATE_KEY=%4

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


SET ARCHIVE_FILENAME=blog_uploads_backup.tgz
SET LOCAL_OUTPUT_DIRECTORY=%USERPROFILE%\Documents\example-blog

SET OLD_HOST_BLOG_DIR=/home/ec2-user/example-blog
SET OLD_HOST_USERNAME=ec2-user
SET OLD_HOST_OUTPUT_DIR=/home/ec2-user


SET NEW_HOST_BLOG_DIR=/home/ec2-user/example-blog
SET NEW_HOST_USERNAME=ec2-user
SET NEW_HOST_OUTPUT_DIR=/home/ec2-user


SET OLD_HOST_UPLOADS_DIR=/public_html/wp-content/uploads
SET NEW_HOST_UPLOADS_DIR=/public_html/wp-content/uploads

echo "Starting backup of blog images..."

ssh -i "%OLD_SERVER_PRIVATE_KEY%" %OLD_HOST_USERNAME%@%OLD_HOST% "tar --force-local -czf %OLD_HOST_OUTPUT_DIR%/%ARCHIVE_FILENAME% --exclude=%OLD_HOST_BLOG_DIR%/public_html/wp-content/cache/adaptive-images/* --directory %OLD_HOST_BLOG_DIR%/public_html/wp-content/ uploads"

@REM secure copy from old server while preserving modification/access/mode of original file...
echo "Copying remote archive to local machine..."
scp -i "%OLD_SERVER_PRIVATE_KEY%" -p %OLD_HOST_USERNAME%@%OLD_HOST%:%OLD_HOST_OUTPUT_DIR%/%ARCHIVE_FILENAME% "%LOCAL_OUTPUT_DIRECTORY%\%ARCHIVE_FILENAME%"

@REM secure copy to new  server while preserving modification/access/mode of original file...
echo "Copying archive to new server..."
scp -i "%NEW_SERVER_PRIVATE_KEY%" -p "%LOCAL_OUTPUT_DIRECTORY%\%ARCHIVE_FILENAME%" %NEW_HOST_USERNAME%@%NEW_HOST%:%NEW_HOST_OUTPUT_DIR%/%ARCHIVE_FILENAME%

@REM extract the backup on the new server...
echo "Extracting archive on new server..."
ssh -i "%NEW_SERVER_PRIVATE_KEY%" %NEW_HOST_USERNAME%@%NEW_HOST% "tar --force-local -xvf %NEW_HOST_OUTPUT_DIR%/%ARCHIVE_FILENAME% --directory %NEW_HOST_BLOG_DIR%/public_html/wp-content/"

@REM make sure the files have the proper permissions
echo "Setting permissions on files..."
ssh -i "%NEW_SERVER_PRIVATE_KEY%" %NEW_HOST_USERNAME%@%NEW_HOST% "chown -R ec2-user:apache %NEW_HOST_BLOG_DIR%/public_html/wp-content/uploads"


echo "DONE!'

