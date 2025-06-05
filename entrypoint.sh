#!/bin/bash
set -e

# Output message to show that container is starting
echo "MongoDB backup container starting..."

# Make sure timezone is properly set
echo "Current timezone: $(date +%Z)"
echo "Current time: $(date)"

# Install the crontab at container startup (more reliable than during build)
echo "Installing crontab..."
crontab /etc/cron.d/backup-cron
echo "Crontab installed:"
crontab -l

# Start the cron daemon
echo "Starting cron daemon..."
cron -f &
CRON_PID=$!

# Run an initial backup if requested
if [ "${RUN_ON_STARTUP}" = "true" ]; then
    echo "Running initial backup..."
    /app/backup.sh
    echo "Initial backup completed."
fi

# Keep container running and follow the logs
echo "Container started successfully. Tailing logs..."
tail -f /var/log/cron.log &

# Wait for cron process
wait $CRON_PID
