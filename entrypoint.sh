#!/bin/bash
set -e

# Output message to show that container is starting
echo "MongoDB backup container starting..."

# Make sure timezone is properly set
echo "Current timezone: $(date +%Z)"

# Confirm cron service is installed
if ! command -v cron &> /dev/null; then
    echo "ERROR: cron not installed"
    exit 1
fi

# Display current cron configuration
echo "Current cron configuration:"
crontab -l

# Create the log file if it doesn't exist
if [ ! -f /var/log/cron.log ]; then
    touch /var/log/cron.log
    chmod 0644 /var/log/cron.log
fi

# Verify backup script exists and is executable
if [ ! -x /app/backup.sh ]; then
    echo "ERROR: /app/backup.sh not executable"
    exit 1
fi

# Run a manual backup first to make sure everything is working
echo "Running initial backup test..."
/app/backup.sh &> /var/log/initial-backup.log
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Initial backup test failed. Check /var/log/initial-backup.log"
else
    echo "Initial backup test completed successfully"
fi

# Start the cron service in the foreground
echo "Starting cron service..."
cron

# Keep container running and follow the logs
echo "Container started successfully. Tailing logs..."
exec tail -f /var/log/cron.log
