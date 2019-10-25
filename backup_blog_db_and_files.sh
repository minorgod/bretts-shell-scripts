#!/bin/sh

NOW=$(date +"%Y_%m_%d_%T%z")
DB_HOST=localhost
DB_USER=wordpress-user
DB_PASSWORD=somesupersecretpassword
DB_NAME=wordpress
SQL_FILENAME="${DB_NAME}_${NOW}.sql"
ARCHIVE_FILENAME="blog_${NOW}.tgz"
BLOG_DIR="/home/ec2-user/blog"

echo "Starting backup of ${DB_NAME}..."
mysqldump --host=$DB_HOST --user=$DB_USER --password=$DB_PASSWORD $DB_NAME > "${SQL_FILENAME}"
echo "Created database dump: ${SQL_FILENAME}" 
echo "Now backing up blog files..."

tar --force-local -czf "${ARCHIVE_FILENAME}" \
	--exclude "${BLOG_DIR}/wp-content/cache/adaptive-images/*" \
"${BLOG_DIR}" "${SQL_FILENAME}"

echo "Removing uncompressed sql file..."
rm -f "${SQL_FILENAME}"
echo "Done!"
echo "Backup saved to: ${ARCHIVE_FILENAME}"

 
