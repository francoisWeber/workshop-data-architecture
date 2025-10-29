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
  done
else
  echo "[start.sh] No users.csv found at $USERS_CSV (skipping user creation)"
fi

exec jupyterhub -f /srv/jupyterhub/jupyterhub_config.py
