# JupyterHub Users Setup

1. Edit `jupyterhub/users/students.txt` and list one student name per line.
2. Generate usernames and passwords (also adds allowlist and admins):

```bash
python3 scripts/generate_user_credentials.py --admins "Instructor Name"
```

This writes:
- `jupyterhub/users/users.csv` and a timestamped backup
- `jupyterhub/users/allowlist.txt`
- `jupyterhub/users/admins.txt`

3. Start/restart the stack. On container start, the Hub creates Linux users from `users.csv` and enables access for the allowlist.

- JupyterHub URL: http://localhost:8000
- Use the generated username/password per user.
