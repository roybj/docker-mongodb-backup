#!/bin/bash

# Simple script to test if cron is working
# This creates a test cron job that runs every minute

echo "Setting up test cron job (runs every minute)..."

# Create test script
cat > /app/test-backup.sh << 'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test cron job executed successfully!" >> /var/log/cron.log
EOF

chmod +x /app/test-backup.sh

# Create test cron job
echo "SHELL=/bin/bash" > /etc/cron.d/test-cron
echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/cron.d/test-cron
echo "* * * * * root /app/test-backup.sh" >> /etc/cron.d/test-cron
echo "" >> /etc/cron.d/test-cron

chmod 0644 /etc/cron.d/test-cron

# Restart cron
service cron restart

echo "Test cron job created. Check /var/log/cron.log for messages every minute."
echo "To remove test cron: rm /etc/cron.d/test-cron && service cron restart"

# Show last few log entries
echo "Current log tail:"
tail -5 /var/log/cron.log
