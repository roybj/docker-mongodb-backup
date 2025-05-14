# Use an official lightweight Python image
FROM python:3.9-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    cron \
    awscli \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Add MongoDB repository
RUN wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" > /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && apt-get install -y mongodb-org-tools && \
    rm -rf /var/lib/apt/lists/*

# Pull the timezone from the .env file
ARG TZ
ENV TZ=$TZ
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set the working directory
WORKDIR /app

# Copy the backup script and cronjob file
COPY backup.sh /app/backup.sh
COPY cronjob /etc/cron.d/backup-cron

# Make the backup script executable
RUN chmod +x /app/backup.sh

# Apply cron job
RUN crontab /etc/cron.d/backup-cron

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Start the cron service
CMD ["cron", "-f"]