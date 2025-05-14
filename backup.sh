#!/bin/bash

# Ensure the timezone is set from the .env file
export TZ=${TZ:-UTC}

# Load environment variables
source "/app/.env"

# Set default retention period if not defined
RETENTION_PERIOD=${RETENTION_PERIOD:-30}

# Get the current date
DATE=$(date +"%Y-%m-%d")

# Create a temporary directory for backups
BACKUP_DIR="/tmp/mongo_backups_$DATE"
mkdir -p "$BACKUP_DIR"

# Get a list of all databases
DATABASES=$(mongo --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p '$MONGO_PASSWORD' --authenticationDatabase admin --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join(' ')" 2>/dev/null)

# Backup each database individually
for DB in $DATABASES; do
    mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p '$MONGO_PASSWORD' --authenticationDatabase admin --db "$DB" --out "$BACKUP_DIR/$DB"
done

# Compress the backups
BACKUP_ARCHIVE="/tmp/mongo_backup_$DATE.tar.gz"
tar -czf "$BACKUP_ARCHIVE" -C "$BACKUP_DIR" .

# Ensure the S3 backup path exists
aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/" 2>/dev/null || aws s3api put-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/"

# Update the backup path to include the directory
BACKUP_PATH="$S3_BACKUP_PATH/mongo_backup_$DATE.tar.gz"

# Upload to S3
aws s3 cp "$BACKUP_ARCHIVE" "s3://$S3_BUCKET/$BACKUP_PATH" --storage-class STANDARD

# Clean up local backups
rm -rf "$BACKUP_DIR"
rm -f "$BACKUP_ARCHIVE"

# Delete old backups from S3
aws s3 ls "s3://$S3_BUCKET/$S3_BACKUP_PATH/" | awk '{print $4}' | while read -r FILE; do
    FILE_DATE=$(echo "$FILE" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
    if [[ "$FILE_DATE" < $(date -d "$RETENTION_PERIOD days ago" +"%Y-%m-%d") ]]; then
        aws s3 rm "s3://$S3_BUCKET/$S3_BACKUP_PATH/$FILE"
    fi
done