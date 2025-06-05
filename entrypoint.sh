#!/bin/bash
set -e

# Output message to show that container is starting
echo "MongoDB backup container starting..."

# Make sure timezone is properly set
echo "Current timezone: $(date +%Z)"
echo "Current time: $(date)"

# Confirm cron service is installed
if ! command -v cron &> /dev/null; then
    echo "ERROR: cron not installed"
    exit 1
fi

# Display current cron configuration
echo "Current cron configuration:"
crontab -l

# Start the cron daemon
echo "Starting cron daemon..."
service cron start || cron

# Keep container running and follow the logs
echo "Container started successfully. Tailing logs..."
touch /var/log/cron.log
tail -f /var/log/cron.log
