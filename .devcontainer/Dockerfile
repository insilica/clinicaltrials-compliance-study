FROM mcr.microsoft.com/vscode/devcontainers/python:3.9

# Install system dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    postgresql-client \
    wget \
    r-base \
    libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://get.docker.com | sh

# Install DVC
RUN pip install --no-cache-dir dvc

# Install R packages
RUN R -e "install.packages(c('cthist', 'arrow', 'DBI', 'RPostgres', 'dotenv', 'dplyr', 'doFuture', 'fs', 'purrr'), repos='https://cloud.r-project.org/')"

# Copy requirements.txt and install Python dependencies
COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
