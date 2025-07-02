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
printenv | grep -vE '^(PWD|OLDPWD|SHLVL|_|CRON_PID)' > /app/cogen.env

# Update cron command to match original format + environment loading
echo "SHELL=/bin/bash" > /etc/cron.d/backup-cron
echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/cron.d/backup-cron
echo "0 2 * * * root . /app/cogen.env; /app/backup.sh >> /var/log/cron.log 2>&1" >> /etc/cron.d/backup-cron

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

# Run initial backup if requested
if [ "${RUN_ON_STARTUP,,}" = "true" ]; then
    echo "Running initial backup..."
    . /app/cogen.env
    /app/backup.sh
    echo "Initial backup completed at $(date)"
fi

echo "Container started. Tailing cron logs..."
tail -F /var/log/cron.log