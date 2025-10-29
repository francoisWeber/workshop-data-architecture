#!/usr/bin/env bash
set -euo pipefail

USERS_DIR="/srv/jupyterhub/users"
USERS_CSV="$USERS_DIR/users.csv"

if [ -f "$USERS_CSV" ]; then
  echo "[start.sh] Creating users from $USERS_CSV"
  # CSV header: name,username,password,is_admin
  tail -n +2 "$USERS_CSV" | while IFS=, read -r name username password is_admin; do
    # Strip whitespace
    username="$(echo "$username" | xargs)"
    password="$(echo "$password" | xargs)"
    [ -z "$username" ] && continue

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
