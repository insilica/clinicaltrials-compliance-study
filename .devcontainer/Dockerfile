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
<<<<<<< HEAD
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
=======
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli

# Install DVC
RUN pip install dvc

# Install R packages
RUN R -e "install.packages(c('cthist', 'arrow', 'DBI', 'RPostgres', 'dotenv', 'dplyr', 'doFuture', 'fs', 'purrr'), repos='http://cran.rstudio.com/')"

# Copy requirements.txt and install Python dependencies
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

# Copy flake.nix and flake.lock and install dependencies
# COPY flake.nix flake.lock /tmp/
# RUN nix-shell --pure flake.nix -A python39Packages.pandas -A python39Packages.pyarrow -A python39Packages.openpyxl

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
>>>>>>> 5cc6a1c (rebase on main)
