#!/bin/bash
set -e

echo "MongoDB backup container starting..."

# Set system timezone from $TZ
if [ -n "$TZ" ]; then
    echo "Setting timezone to $TZ"
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
fi

echo "Current timezone: $(date +%Z)"
echo "Current time: $(date)"

# Create environment file for cron
echo "Creating environment file..."
# Export all current environment variables to the cogen.env file
printenv | grep -vE '^(PWD|OLDPWD|SHLVL|_|CRON_PID)' | while IFS='=' read -r name value; do
    # Properly escape the value and export it
    echo "export $name='$value'" >> /app/cogen.env
done

# Verify the environment file contains our MongoDB and S3 variables
echo "Environment file created. Key variables:"
grep -E '^export (MONGO_|S3_|AWS_|TZ|RETENTION_)' /app/cogen.env || echo "Warning: Some environment variables may be missing"

# Debug: Show all environment variables for troubleshooting
echo "Debug: All environment variables in cogen.env:"
cat /app/cogen.env | head -20

# Set up cron schedule - use CRON_TIME if provided, otherwise default to 2 AM daily
CRON_SCHEDULE="${CRON_TIME:-0 2 * * *}"
echo "Setting up cron job with schedule: $CRON_SCHEDULE"

# Update cron command to match original format + environment loading
echo "SHELL=/bin/bash" > /etc/cron.d/backup-cron
echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/cron.d/backup-cron
echo "$CRON_SCHEDULE root . /app/cogen.env; /app/backup.sh >> /var/log/cron.log 2>&1" >> /etc/cron.d/backup-cron
echo "" >> /etc/cron.d/backup-cron  # Important: cron files need to end with a newline

# Ensure proper permissions
chmod 0644 /etc/cron.d/backup-cron

echo "Cron job contents:"
cat /etc/cron.d/backup-cron

# Initialize log file
touch /var/log/cron.log
echo "Cron initialized at $(date)" >> /var/log/cron.log

# Start cron service
echo "Starting cron service..."
service cron start

# Verify cron service is running
if ! service cron status > /dev/null 2>&1; then
    echo "ERROR: Cron service failed to start!"
    exit 1
fi

# Restart cron to ensure it picks up the new job
service cron restart
echo "Cron service restarted and running"

# List active cron jobs for verification
echo "Active cron jobs:"
crontab -l 2>/dev/null || echo "No user crontab"
echo "System cron jobs in /etc/cron.d/:"
ls -la /etc/cron.d/

# Run initial backup if requested
if [ "${RUN_ON_STARTUP,,}" = "true" ]; then
    echo "Running initial backup..."
    . /app/cogen.env
    /app/backup.sh
    echo "Initial backup completed at $(date)"
fi

# Add a cron monitoring function
monitor_cron() {
    while true; do
        sleep 3600  # Check every hour
        if ! service cron status > /dev/null 2>&1; then
            echo "WARNING: Cron service stopped! Restarting..."
            service cron start
        fi
    done
}

# Start cron monitoring in background
monitor_cron &

echo "Container started. Cron is scheduled to run: $CRON_SCHEDULE"
echo "Next scheduled run: $(date -d 'tomorrow 02:00' 2>/dev/null || echo 'Check logs for actual schedule')"
echo "Tailing cron logs..."
tail -F /var/log/cron.log