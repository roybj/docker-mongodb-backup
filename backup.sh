#!/bin/bash

# Ensure the timezone is set from environment variables
export TZ=${TZ:-UTC}

# No need to source .env file as variables will be provided by Caprover
# Set default values for required variables if not provided
MONGO_HOST=${MONGO_HOST:-localhost}
MONGO_PORT=${MONGO_PORT:-27017}
MONGO_USER=${MONGO_USER:-admin}
MONGO_PASSWORD=${MONGO_PASSWORD:-password}
S3_BUCKET=${S3_BUCKET:-backup-bucket}
S3_BACKUP_PATH=${S3_BACKUP_PATH:-mongodb-backups}
S3_ENDPOINT=${S3_ENDPOINT:-"https://s3.amazonaws.com"}

# Set default retention period if not defined
RETENTION_PERIOD=${RETENTION_PERIOD:-30}

# Get the current date
DATE=$(date +"%Y-%m-%d")

# Create a temporary directory for backups
BACKUP_DIR="/tmp/mongo_backups_$DATE"
mkdir -p "$BACKUP_DIR"

# Get a list of all databases
DATABASES=$(mongosh --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join(' ')" 2>/dev/null)

# Backup each database individually
for DB in $DATABASES; do
    mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase admin --db "$DB" --out "$BACKUP_DIR/$DB"
done

# Compress the backups
BACKUP_ARCHIVE="/tmp/mongo_backup_$DATE.tar.gz"
tar -czf "$BACKUP_ARCHIVE" -C "$BACKUP_DIR" .

# Ensure the S3 backup path exists
aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT" 2>/dev/null || aws s3api put-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT"

# Update the backup path to include the directory
BACKUP_PATH="$S3_BACKUP_PATH/mongo_backup_$DATE.tar.gz"

# Upload to S3
aws s3 cp "$BACKUP_ARCHIVE" "s3://$S3_BUCKET/$BACKUP_PATH" --storage-class STANDARD --endpoint-url "$S3_ENDPOINT"

# Clean up local backups
rm -rf "$BACKUP_DIR"
rm -f "$BACKUP_ARCHIVE"

# Delete old backups from S3
# Calculate the cutoff date for retention
CUTOFF_DATE=$(date -d "$RETENTION_PERIOD days ago" +"%Y-%m-%d")

# List files in S3 bucket and delete old backups
aws s3 ls "s3://$S3_BUCKET/$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT" | awk '{print $4}' | while read -r FILE; do
    # Extract date from filename using regex
    if [[ $FILE =~ mongo_backup_([0-9]{4}-[0-9]{2}-[0-9]{2})\.tar\.gz ]]; then
        FILE_DATE="${BASH_REMATCH[1]}"
        # Compare dates as strings (YYYY-MM-DD format allows for string comparison)
        if [[ "$FILE_DATE" < "$CUTOFF_DATE" ]]; then
            echo "Deleting old backup: $FILE (date: $FILE_DATE, cutoff: $CUTOFF_DATE)"
            aws s3 rm "s3://$S3_BUCKET/$S3_BACKUP_PATH/$FILE" --endpoint-url "$S3_ENDPOINT"
        fi
    fi
done