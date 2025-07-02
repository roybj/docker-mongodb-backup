#!/bin/bash

# Health check script to verify cron is working properly

echo "=== Cron Health Check ==="
echo "Date: $(date)"
echo ""

# Check if cron service is running
echo "1. Checking cron service status:"
if service cron status > /dev/null 2>&1; then
    echo "   ✅ Cron service is running"
else
    echo "   ❌ Cron service is NOT running"
    exit 1
fi

# Check if cron files exist
echo ""
echo "2. Checking cron configuration files:"
if [ -f /etc/cron.d/backup-cron ]; then
    echo "   ✅ Backup cron file exists"
    echo "   Content:"
    cat /etc/cron.d/backup-cron | sed 's/^/      /'
else
    echo "   ❌ Backup cron file missing"
fi

# Check environment file
echo ""
echo "3. Checking environment file:"
if [ -f /app/cogen.env ]; then
    echo "   ✅ Environment file exists"
    echo "   Variables count: $(wc -l < /app/cogen.env)"
else
    echo "   ❌ Environment file missing"
fi

# Check backup script
echo ""
echo "4. Checking backup script:"
if [ -x /app/backup.sh ]; then
    echo "   ✅ Backup script is executable"
else
    echo "   ❌ Backup script missing or not executable"
fi

# Check recent cron activity
echo ""
echo "5. Recent cron log activity (last 10 lines):"
if [ -f /var/log/cron.log ]; then
    tail -10 /var/log/cron.log | sed 's/^/   /'
else
    echo "   ❌ Cron log file missing"
fi

# Check system cron logs
echo ""
echo "6. System cron activity:"
journalctl -u cron --no-pager -n 5 2>/dev/null | sed 's/^/   /' || echo "   (journalctl not available)"

echo ""
echo "=== End Health Check ==="
