#!/usr/bin/env bash
set -euo pipefail

USERS_DIR="/srv/jupyterhub/users"
USERS_CSV="$USERS_DIR/users.csv"
ADMIN_PASSWORD_FILE="$USERS_DIR/admin_password.txt"

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

The workshop datasets are available in read-only mode at:
  /datasets/

Available dataset directories:
  - /datasets/sql/       - SQL dump files for database initialization
  - /datasets/csv/       - CSV formatted data files
  - /datasets/cliclog/   - Click log interactions data
  - /datasets/vespa/     - Vespa search engine data (JSONL format)

These directories are mounted read-only, so you cannot modify them.
Copy files to your home directory or /work if you need to make changes.

Example usage in Python:
  import pandas as pd
  df = pd.read_csv('/datasets/csv/yourfile.csv')

Example usage in Shell:
  ls -la /datasets/
  cp /datasets/csv/yourfile.csv ~/my-copy.csv
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
