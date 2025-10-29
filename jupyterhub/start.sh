#!/usr/bin/env bash
set -euo pipefail

USERS_DIR="/srv/jupyterhub/users"
USERS_CSV="$USERS_DIR/users.csv"
ADMIN_PASSWORD_FILE="/srv/jupyterhub/admin.password"

# Load admin password from file if it exists
ADMIN_PASSWORD=""
if [ -f "$ADMIN_PASSWORD_FILE" ]; then
  ADMIN_PASSWORD="$(cat "$ADMIN_PASSWORD_FILE" | xargs)"
  echo "[start.sh] Loaded admin password from $ADMIN_PASSWORD_FILE"
fi

if [ -f "$USERS_CSV" ]; then
  echo "[start.sh] Creating users from $USERS_CSV"
  # CSV header: name,username,password,is_admin
  tail -n +2 "$USERS_CSV" | while IFS=, read -r name username password is_admin; do
    # Strip whitespace
    username="$(echo "$username" | xargs)"
    password="$(echo "$password" | xargs)"
    [ -z "$username" ] && continue

    # Override admin password if static password is configured
    if [ "$username" = "admin" ] && [ -n "$ADMIN_PASSWORD" ]; then
      password="$ADMIN_PASSWORD"
      echo "  - Using static password for admin user"
    fi

    if id -u "$username" >/dev/null 2>&1; then
      echo "  - User exists: $username"
    else
      echo "  - Adding user: $username"
      useradd -m -s /bin/bash "$username" || true
    fi

    if [ -n "$password" ]; then
      echo "$username:$password" | chpasswd || true
    fi

    # Create README for datasets in user's home directory
    USER_HOME="/home/$username"
    if [ -d "$USER_HOME" ]; then
      cat > "$USER_HOME/README_DATASETS.txt" <<'EOF'
# Workshop Datasets

## Access Methods

### 1. Direct File Access (Read-Only)
All datasets are mounted at /datasets/

  import pandas as pd
  df = pd.read_csv('/datasets/csv/beers.csv')

### 2. S3 Access via MinIO (Anonymous - RECOMMENDED!)
After running 'make init-minio', datasets are available via S3 without credentials:

  import pandas as pd
  df = pd.read_csv(
      's3://workshop-data/csv/beers.csv',
      storage_options={
          'client_kwargs': {
              'endpoint_url': 'http://minio:9000'
          }
      }
  )

See /work/s3_pandas_examples.py for more examples!

## Available Datasets

### CSV Files (also in S3: s3://workshop-data/csv/)
  - categories.csv          - Beer categories
  - styles.csv              - Beer styles
  - breweries.csv           - Brewery information
  - breweries_geocode.csv   - Brewery geocodes
  - beers.csv               - Beer details

### Other Formats
  - /datasets/sql/       - SQL dump files
  - /datasets/cliclog/   - Click log interactions data
  - /datasets/vespa/     - Vespa search engine data (JSONL)

## S3 Information
  - Endpoint: http://minio:9000
  - Bucket: workshop-data (PUBLIC READ ACCESS)
  - Console: http://localhost:9001 (from host)

## Shell Commands
  ls -la /datasets/
  cp /datasets/csv/beers.csv ~/my-copy.csv
EOF
      chown "$username:$username" "$USER_HOME/README_DATASETS.txt" 2>/dev/null || true
      chmod 644 "$USER_HOME/README_DATASETS.txt" 2>/dev/null || true
    fi
  done
else
  echo "[start.sh] No users.csv found at $USERS_CSV (skipping user creation)"
fi

# Verify datasets directory is accessible
if [ -d "/datasets" ]; then
  echo "[start.sh] Datasets directory mounted at /datasets (read-only)"
  ls -la /datasets/ 2>/dev/null || echo "  Warning: Could not list /datasets directory"
else
  echo "[start.sh] Warning: /datasets directory not found"
fi

exec jupyterhub -f /srv/jupyterhub/jupyterhub_config.py
