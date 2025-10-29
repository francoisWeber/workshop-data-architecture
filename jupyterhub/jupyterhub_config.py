import os
import pathlib

c = get_config()  # noqa: F821 - provided by jupyterhub runtime

# Hub binding
c.JupyterHub.bind_url = "http://:8000"

# Authentication: PAM (Linux users created in container at startup)
c.JupyterHub.authenticator_class = "jupyterhub.auth.PAMAuthenticator"

# Load allowed and admin users from files if present
users_dir = pathlib.Path("/srv/jupyterhub/users")
allowlist_file = users_dir / "allowlist.txt"
admins_file = users_dir / "admins.txt"

if allowlist_file.exists():
    with allowlist_file.open() as f:
        allow = {line.strip() for line in f if line.strip() and not line.startswith("#")}
        if allow:
            c.Authenticator.allowed_users = allow

admin_users = set()
admin_users_env = os.environ.get("JUPYTERHUB_ADMIN_USERS", "").strip()
if admin_users_env:
    admin_users.update({u.strip() for u in admin_users_env.split(",") if u.strip()})
if admins_file.exists():
    with admins_file.open() as f:
        admin_users.update({line.strip() for line in f if line.strip() and not line.startswith("#")})
if admin_users:
    c.Authenticator.admin_users = admin_users

# Use the default LocalProcessSpawner to run all users in the same container
# c.JupyterHub.spawner_class = "jupyterhub.spawner.SimpleLocalProcessSpawner"
# (default spawner is already LocalProcessSpawner, no need to set it explicitly)

# Users will run as local processes within this container
# Each user gets their own home directory at /home/{username}

# Start JupyterLab by default
c.Spawner.default_url = "/lab"

# Increase default timeouts for first-run pulls and slower environments
c.Spawner.http_timeout = 120
c.Spawner.start_timeout = 180
