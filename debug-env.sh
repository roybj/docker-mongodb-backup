#!/bin/bash

echo "=== Environment Debug Script ==="
echo "Current date: $(date)"
echo ""

echo "1. Environment variables from CapRover:"
echo "MONGO_HOST: ${MONGO_HOST:-'NOT SET'}"
echo "MONGO_PORT: ${MONGO_PORT:-'NOT SET'}"
echo "MONGO_USER: ${MONGO_USER:-'NOT SET'}"
echo "S3_BUCKET: ${S3_BUCKET:-'NOT SET'}"
echo "S3_BACKUP_PATH: ${S3_BACKUP_PATH:-'NOT SET'}"
echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:+SET}"
echo "AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:+SET}"
echo ""

echo "2. Environment file content:"
if [ -f /app/cogen.env ]; then
    echo "File exists. MongoDB related variables:"
    grep -E 'MONGO_|S3_|AWS_' /app/cogen.env || echo "No MongoDB/S3 variables found"
    echo ""
    echo "First 10 lines of environment file:"
    head -10 /app/cogen.env
else
    echo "Environment file /app/cogen.env does not exist!"
fi

echo ""
echo "3. Testing environment sourcing:"
if [ -f /app/cogen.env ]; then
    echo "Before sourcing - MONGO_HOST: ${MONGO_HOST:-'NOT SET'}"
    . /app/cogen.env
    echo "After sourcing - MONGO_HOST: ${MONGO_HOST:-'NOT SET'}"
else
    echo "Cannot test - environment file missing"
fi

echo ""
echo "4. Cron job configuration:"
if [ -f /etc/cron.d/backup-cron ]; then
    cat /etc/cron.d/backup-cron
else
    echo "Cron job file not found!"
fi

echo ""
echo "=== End Debug ==="
