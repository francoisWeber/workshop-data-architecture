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

# Use DockerSpawner to spawn per-user notebook containers
c.JupyterHub.spawner_class = "dockerspawner.DockerSpawner"

# The image for single-user notebook servers (PySpark included)
c.DockerSpawner.image = os.environ.get("JUPYTER_SPAWN_IMAGE", "jupyter/pyspark-notebook:latest")

# Attach spawned containers to the compose network
network_name = os.environ.get("DOCKER_NETWORK_NAME", "workshop-net")
c.DockerSpawner.network_name = network_name
c.DockerSpawner.use_internal_ip = True

# Tell spawned containers how to reach the Hub (crucial for Docker-in-Docker setup)
c.JupyterHub.hub_connect_ip = "jupyterhub"

# Clean up containers when servers stop
c.DockerSpawner.remove = True

# Per-user persistent work volume and shared dataset from host path
host_root = os.environ.get("HOST_PROJECT_ROOT", "/Users/francois.weber/code/workshop-data-architecture")
c.DockerSpawner.volumes = {
    "work-{username}": {"bind": "/home/jovyan/work", "mode": "rw"},
    f"{host_root}/dataset": {"bind": "/home/jovyan/datasets", "mode": "ro"},
}

# Start JupyterLab by default
c.Spawner.default_url = "/lab"

# Increase default timeouts for first-run pulls and slower environments
c.Spawner.http_timeout = 120
c.Spawner.start_timeout = 180
