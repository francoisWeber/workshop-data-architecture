#!/usr/bin/env bash
set -euo pipefail

USERS_DIR="/srv/jupyterhub/users"
USERS_CSV="$USERS_DIR/users.csv"
ADMIN_PASSWORD_FILE="/srv/jupyterhub/admin.password"
SHARED_DIR="/shared"

# Load admin password from file if it exists
ADMIN_PASSWORD=""
if [ -f "$ADMIN_PASSWORD_FILE" ]; then
  ADMIN_PASSWORD="$(cat "$ADMIN_PASSWORD_FILE" | xargs)"
  echo "[start.sh] Loaded admin password from $ADMIN_PASSWORD_FILE"
fi

# Get host UID/GID for admin user (to match host permissions)
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
WORKSHOP_GID=999

echo "[start.sh] Configuring shared directory with host UID:GID = $HOST_UID:$HOST_GID"

# Create workshop group for shared access
if ! getent group workshop >/dev/null 2>&1; then
  groupadd -g $WORKSHOP_GID workshop || echo "  Warning: Could not create workshop group"
  echo "[start.sh] Created workshop group (GID: $WORKSHOP_GID)"
fi

# Set up shared directory with proper permissions
if [ -d "$SHARED_DIR" ]; then
  # Create a staff group if it doesn't exist (for admin's primary group on macOS compatibility)
  if ! getent group staff >/dev/null 2>&1; then
    groupadd -g $HOST_GID staff 2>/dev/null || true
  fi
  
  # Set ownership: admin user will own it, workshop group for shared access
  chown -R $HOST_UID:$WORKSHOP_GID "$SHARED_DIR" 2>/dev/null || echo "  Warning: Could not change ownership of $SHARED_DIR"
  
  # Set permissions: owner RW, group R (read-only), others R
  # Directories: 2755 (rwxr-xr-x with setgid) - group can read and traverse
  # Files: 0644 (rw-r--r--) - group can only read
  find "$SHARED_DIR" -type d -exec chmod 2755 {} \; 2>/dev/null || echo "  Warning: Could not set directory permissions"
  find "$SHARED_DIR" -type f -exec chmod 0644 {} \; 2>/dev/null || echo "  Warning: Could not set file permissions"
  
  echo "[start.sh] Shared directory configured: owner=$HOST_UID:$WORKSHOP_GID, dirs=2755, files=0644 (group read-only)"
else
  echo "[start.sh] Warning: $SHARED_DIR not found"
fi

# Set up work directory with proper permissions (collaborative workspace)
WORK_DIR="/work"
if [ -d "$WORK_DIR" ]; then
  # World-writable but with sticky bit (users can only delete own files)
  chmod 1777 "$WORK_DIR" 2>/dev/null || echo "  Warning: Could not set permissions on $WORK_DIR"
  echo "[start.sh] Work directory configured: mode=1777 (sticky bit, world-writable)"
else
  echo "[start.sh] Warning: $WORK_DIR not found"
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

    # Check if user exists
    if id -u "$username" >/dev/null 2>&1; then
      echo "  - User exists: $username"
    else
      # Create user with specific UID for admin to match host
      if [ "$username" = "admin" ]; then
        echo "  - Adding admin user with UID=$HOST_UID (matching host)"
        useradd -m -s /bin/bash -u $HOST_UID -g $HOST_GID "$username" 2>/dev/null || \
          useradd -m -s /bin/bash -u $HOST_UID "$username" 2>/dev/null || \
          useradd -m -s /bin/bash "$username" || true
      else
        echo "  - Adding user: $username"
        useradd -m -s /bin/bash "$username" || true
      fi
    fi

    if [ -n "$password" ]; then
      echo "$username:$password" | chpasswd || true
    fi

    # Add users to workshop group for shared directory access
    usermod -a -G workshop "$username" 2>/dev/null || echo "  Warning: Could not add $username to workshop group"
    
    # For admin, ensure proper group membership
    if [ "$username" = "admin" ]; then
      # Add admin to staff group (if exists) for macOS compatibility
      usermod -a -G staff "$username" 2>/dev/null || true
      echo "  - Admin configured with UID=$HOST_UID, member of workshop group"
    fi

    # Set up user's home directory
    USER_HOME="/home/$username"
    if [ -d "$USER_HOME" ]; then
      # Fix home directory ownership (critical for users with custom UIDs)
      # Ensure user owns their home directory and all contents
      chown -R "$username:$(id -gn $username)" "$USER_HOME" 2>/dev/null || echo "  Warning: Could not fix ownership for $USER_HOME"
      # Ensure proper permissions for home directory
      chmod 755 "$USER_HOME" 2>/dev/null || true
      echo "  - Fixed ownership of $USER_HOME"
      
      # Create symlink to shared directory (lecture materials)
      if [ ! -e "$USER_HOME/shared" ]; then
        ln -sf "$SHARED_DIR" "$USER_HOME/shared" 2>/dev/null || echo "  Warning: Could not create shared symlink for $username"
      fi
      
      # Create symlink to work directory (collaborative workspace)
      if [ ! -e "$USER_HOME/work" ]; then
        ln -sf "/work" "$USER_HOME/work" 2>/dev/null || echo "  Warning: Could not create work symlink for $username"
      fi
      
      # Log access levels
      if [ "$username" != "admin" ]; then
        echo "  - $username: ~/shared (read-only), ~/work (read-write)"
      else
        echo "  - $username: ~/shared (read-write), ~/work (read-write)"
      fi
      cat > "$USER_HOME/README_DATASETS.txt" <<'EOF'
# Workshop Resources

## Directory Overview

### ~/shared (Lecture Materials) - READ-ONLY for students
- Admin: Read-write access to share lecture materials
- Students: Read-only access to view shared materials
- Location: ~/shared → /shared

Use this for:
- Lecture notebooks shared by instructor
- Exercise templates
- Reference materials
- Viewing instructor's live coding

**Students**: Copy files to your home to edit them!
```bash
cp ~/shared/exercises/ex1.ipynb ~/my-solution.ipynb
```

### ~/work (Collaborative Workspace) - READ-WRITE for everyone
- All users: Read-write access
- Location: ~/work → /work

Use this for:
- Sharing work between users
- Collaborative projects
- Group exercises
- Exchanging files with other students

**Note**: Files here are visible to ALL users!

## Datasets

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
