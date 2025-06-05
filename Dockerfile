# Use an official lightweight Python image
FROM python:3.9-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    cron \
    awscli \
    gnupg \
    less \
    && rm -rf /var/lib/apt/lists/*

# Install wget before adding MongoDB repository
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Install curl and mongosh
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Add MongoDB repository and install mongosh and mongodb-org-tools
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg ] https://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" > /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && apt-get install -y mongodb-mongosh mongodb-org-tools && rm -rf /var/lib/apt/lists/*

# Get timezone from environment variables (provided by Caprover)
ARG TZ
ENV TZ=$TZ
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set the working directory
WORKDIR /app

# Copy the backup script and cronjob file
COPY backup.sh /app/backup.sh
COPY cronjob /etc/cron.d/backup-cron
COPY entrypoint.sh /app/entrypoint.sh

# Make scripts executable
RUN chmod +x /app/backup.sh /app/entrypoint.sh

# Ensure cron.log exists and is writable
RUN touch /var/log/cron.log && chmod 0644 /var/log/cron.log

# Dynamically replace the CRON_TIME placeholder in the cronjob file
RUN sed -i "s|CRON_TIME_PLACEHOLDER|${CRON_TIME:-0 2 * * *}|" /etc/cron.d/backup-cron && \
    echo "" >> /etc/cron.d/backup-cron && \
    chmod 0644 /etc/cron.d/backup-cron && \
    # Register crontab file
    crontab /etc/cron.d/backup-cron && \
    cat /etc/cron.d/backup-cron

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Use the entrypoint script to start cron and tail logs
ENTRYPOINT ["/app/entrypoint.sh"]