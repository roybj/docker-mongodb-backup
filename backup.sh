#!/bin/bash
set -e

# Function for logging with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function for error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

log "Starting MongoDB backup process..."
export TZ=${TZ:-UTC}

# No need to source .env file as variables will be provided by Caprover
# Configure AWS credentials if provided
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
    aws configure set region "${AWS_DEFAULT_REGION:-us-east-1}"
fi

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

# Validate MongoDB connection
log "Testing MongoDB connection to $MONGO_HOST:$MONGO_PORT..."
if ! mongosh --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    handle_error "Cannot connect to MongoDB at $MONGO_HOST:$MONGO_PORT"
fi
log "MongoDB connection successful"

# Get the current date
DATE=$(date +"%Y-%m-%d")

# Validate S3 connectivity
log "Testing S3 connectivity to bucket $S3_BUCKET..."
if ! aws s3 ls "s3://$S3_BUCKET" --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1; then
    handle_error "Cannot access S3 bucket $S3_BUCKET at $S3_ENDPOINT"
fi
log "S3 connectivity successful"

# Create a temporary directory for backups
BACKUP_DIR="/tmp/mongo_backups_$DATE"
mkdir -p "$BACKUP_DIR"

# Get a list of all databases
log "Fetching database list..."
DATABASES=$(mongosh --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join(' ')" 2>/dev/null)

if [ -z "$DATABASES" ]; then
    handle_error "No databases found or unable to fetch database list"
fi

log "Found databases: $DATABASES"

# Backup each database individually
for DB in $DATABASES; do
    # Skip system databases if desired
    if [[ "$DB" == "admin" || "$DB" == "config" || "$DB" == "local" ]]; then
        log "Skipping system database: $DB"
        continue
    fi
    
    log "Backing up database: $DB"
    if ! mongodump --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase admin --db "$DB" --out "$BACKUP_DIR/$DB"; then
        handle_error "Failed to backup database: $DB"
    fi
done

# Compress the backups
BACKUP_ARCHIVE="/tmp/mongo_backup_$DATE.tar.gz"
log "Compressing backups to $BACKUP_ARCHIVE..."
if ! tar -czf "$BACKUP_ARCHIVE" -C "$BACKUP_DIR" .; then
    handle_error "Failed to compress backup files"
fi

# Get backup file size for logging
BACKUP_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
log "Backup archive created successfully (size: $BACKUP_SIZE)"

# Ensure the S3 backup path exists
aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT" 2>/dev/null || aws s3api put-object --bucket "$S3_BUCKET" --key "$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT"

# Update the backup path to include the directory
BACKUP_PATH="$S3_BACKUP_PATH/mongo_backup_$DATE.tar.gz"

# Upload to S3
log "Uploading backup to S3: s3://$S3_BUCKET/$BACKUP_PATH"
if ! aws s3 cp "$BACKUP_ARCHIVE" "s3://$S3_BUCKET/$BACKUP_PATH" --storage-class STANDARD --endpoint-url "$S3_ENDPOINT"; then
    handle_error "Failed to upload backup to S3"
fi
log "Backup uploaded successfully to S3"

# Clean up local backups
log "Cleaning up local backup files..."
rm -rf "$BACKUP_DIR"
rm -f "$BACKUP_ARCHIVE"

# Delete old backups from S3
log "Cleaning up old backups (retention: $RETENTION_PERIOD days)..."
# Calculate the cutoff date for retention
CUTOFF_DATE=$(date -d "$RETENTION_PERIOD days ago" +"%Y-%m-%d")

# List files in S3 bucket and delete old backups
aws s3 ls "s3://$S3_BUCKET/$S3_BACKUP_PATH/" --endpoint-url "$S3_ENDPOINT" | awk '{print $4}' | while read -r FILE; do
    # Extract date from filename using regex
    if [[ $FILE =~ mongo_backup_([0-9]{4}-[0-9]{2}-[0-9]{2})\.tar\.gz ]]; then
        FILE_DATE="${BASH_REMATCH[1]}"
        # Compare dates as strings (YYYY-MM-DD format allows for string comparison)
        if [[ "$FILE_DATE" < "$CUTOFF_DATE" ]]; then
            log "Deleting old backup: $FILE (date: $FILE_DATE, cutoff: $CUTOFF_DATE)"
            aws s3 rm "s3://$S3_BUCKET/$S3_BACKUP_PATH/$FILE" --endpoint-url "$S3_ENDPOINT"
        fi
    fi
done

log "Backup process completed successfully!"