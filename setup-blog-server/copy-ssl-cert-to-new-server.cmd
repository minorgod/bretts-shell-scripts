
@echo off

SET LOCAL_OUTPUT_DIRECTORY=%USERPROFILE%\Documents\blog
SET OLD_HOST_SSL_CERT=example.com.crt
SET OLD_HOST_SSL_KEY=example.com.key
SET OLD_HOST_OUTPUT_DIR=/etc/pki/tls/
SET OLD_HOST_USERNAME=ec2-user
SET OLD_HOST=ec2-88-8-888-88.compute-1.amazonaws.com

SET NEW_HOST_SSL_CERT=example.com.crt
SET NEW_HOST_SSL_KEY=example.com.key
SET NEW_HOST_OUTPUT_DIR=/etc/pki/tls/
SET NEW_HOST_USERNAME=ec2-user
SET NEW_HOST=ec2-99-999-999-99.compute-1.amazonaws.com

SET OLD_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key
SET NEW_SERVER_PRIVATE_KEY=%USERPROFILE%\.ssh\example-blog.key

echo "Starting transfer of cert..."

@REM copy certs to accessible
echo copying old cert and key to home directory
ssh -i %OLD_SERVER_PRIVATE_KEY% %OLD_HOST_USERNAME%@%OLD_HOST% "sudo cp %OLD_HOST_OUTPUT_DIR%/certs/%OLD_HOST_SSL_CERT% /home/ec2-user/%OLD_HOST_SSL_CERT%"
ssh -i %OLD_SERVER_PRIVATE_KEY% %OLD_HOST_USERNAME%@%OLD_HOST% "sudo cp %OLD_HOST_OUTPUT_DIR%/private/%OLD_HOST_SSL_KEY% /home/ec2-user/%OLD_HOST_SSL_KEY%"

@REM secure copy from old server while preserving modification/access/mode of original file...
echo copying old cert and key to local machine
scp -i %OLD_SERVER_PRIVATE_KEY% -p %OLD_HOST_USERNAME%@%OLD_HOST%:/home/ec2-user/%OLD_HOST_SSL_CERT% "%LOCAL_OUTPUT_DIRECTORY%\%OLD_HOST_SSL_CERT%"
scp -i %OLD_SERVER_PRIVATE_KEY% -p %OLD_HOST_USERNAME%@%OLD_HOST%:/home/ec2-user/%OLD_HOST_SSL_KEY% "%LOCAL_OUTPUT_DIRECTORY%\%OLD_HOST_SSL_KEY%"

@REM secure copy to new  server while preserving modification/access/mode of original file...
echo copying old cert and key to new server home directory
scp -i %NEW_SERVER_PRIVATE_KEY% -p "%LOCAL_OUTPUT_DIRECTORY%\%NEW_HOST_SSL_CERT%" %NEW_HOST_USERNAME%@%NEW_HOST%:/home/ec2-user/%NEW_HOST_SSL_CERT%
scp -i %NEW_SERVER_PRIVATE_KEY% -p "%LOCAL_OUTPUT_DIRECTORY%\%NEW_HOST_SSL_KEY%" %NEW_HOST_USERNAME%@%NEW_HOST%:/home/ec2-user/%NEW_HOST_SSL_KEY%

@REM move certs to final location
echo moving certs to final location on new server
ssh -i %NEW_SERVER_PRIVATE_KEY% %NEW_HOST_USERNAME%@%NEW_HOST% "sudo mv /home/ec2-user/%NEW_HOST_SSL_CERT% %NEW_HOST_OUTPUT_DIR%/certs/%NEW_HOST_SSL_CERT%"
ssh -i %NEW_SERVER_PRIVATE_KEY% %NEW_HOST_USERNAME%@%NEW_HOST% "sudo mv /home/ec2-user/%NEW_HOST_SSL_KEY% %NEW_HOST_OUTPUT_DIR%/private/%NEW_HOST_SSL_KEY%"