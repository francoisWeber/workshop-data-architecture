#!/usr/bin/env python3
import argparse
import csv
import re
import secrets
import string
import sys
import time
import unicodedata
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
USERS_DIR = ROOT / "jupyterhub" / "users"
JUPYTERHUB_DIR = ROOT / "jupyterhub"
STUDENTS_TXT = USERS_DIR / "students.txt"
USERS_CSV = USERS_DIR / "users.csv"
ALLOWLIST = USERS_DIR / "allowlist.txt"
ADMINS = USERS_DIR / "admins.txt"
ADMIN_PASSWORD_FILE = JUPYTERHUB_DIR / "admin.password"


def normalize_name(name: str) -> str:
    name = name.strip()
    # Fold accents to ASCII
    name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    name = re.sub(r"[^A-Za-z0-9\s-]", "", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name


def username_from_name(name: str) -> str:
    parts = normalize_name(name).lower().split()
    if not parts:
        return "user"
    if len(parts) == 1:
        base = parts[0]
    else:
        base = parts[0][0] + parts[-1]
    base = re.sub(r"[^a-z0-9]", "", base)
    return base or "user"


def unique_usernames(names, extra_reserved=None):
    used = set(extra_reserved or [])
    mapping = {}
    counters = {}
    for name in names:
        base = username_from_name(name)
        if base not in used:
            username = base
            used.add(username)
        else:
            counters.setdefault(base, 1)
            while True:
                candidate = f"{base}{counters[base]}"
                counters[base] += 1
                if candidate not in used:
                    username = candidate
                    used.add(candidate)
                    break
        mapping[name] = username
    return mapping


def random_password(length=16):
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main():
    parser = argparse.ArgumentParser(description="Generate JupyterHub users and passwords from students.txt")
    parser.add_argument("--students", default=str(STUDENTS_TXT), help="Path to students.txt")
    parser.add_argument("--admins", default="admin", help="Comma-separated admin names (default: admin)")
    parser.add_argument("--admin-password-file", default=str(ADMIN_PASSWORD_FILE), help="Path to admin.password file")
    parser.add_argument("--outdir", default=str(USERS_DIR), help="Output directory for users files")
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    students_path = Path(args.students)
    if not students_path.exists():
        print(f"students.txt not found at {students_path}", file=sys.stderr)
        sys.exit(1)

    # Read admin password from file
    admin_password_path = Path(args.admin_password_file)
    if not admin_password_path.exists():
        print(f"admin.password not found at {admin_password_path}", file=sys.stderr)
        sys.exit(1)
    
    with admin_password_path.open() as f:
        admin_password = f.read().strip()
    
    if not admin_password:
        print("admin.password file is empty", file=sys.stderr)
        sys.exit(1)

    # Read input names
    names = []
    with students_path.open() as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            names.append(s)

    if not names:
        print("No student names found in students.txt", file=sys.stderr)
        sys.exit(1)

    admin_names = [s.strip() for s in args.admins.split(",") if s.strip()]

    # Ensure admins are part of the full list too (for credentials)
    full_names = admin_names + names

    # Generate usernames
    uname_map = unique_usernames(full_names)

    # Build rows
    rows = []
    allow = []
    admin_unames = []
    for name in full_names:
        uname = uname_map[name]
        is_admin = name in admin_names
        # Use static password for admin, random for others
        pwd = admin_password if is_admin else random_password()
        rows.append({
            "name": name,
            "username": uname,
            "password": pwd,
            "is_admin": "true" if is_admin else "false",
        })
        allow.append(uname)
        if is_admin:
            admin_unames.append(uname)

    # Write CSV
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    backup_csv = outdir / f"users-{timestamp}.csv"
    fieldnames = ["name", "username", "password", "is_admin"]
    for path in (USERS_CSV, backup_csv):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    # Write allowlist and admins
    with ALLOWLIST.open("w") as f:
        f.write("\n".join(sorted(set(allow))) + "\n")
    with ADMINS.open("w") as f:
        f.write("\n".join(sorted(set(admin_unames))) + "\n")

    print(f"Wrote: \n  {USERS_CSV}\n  {backup_csv}\n  {ALLOWLIST}\n  {ADMINS}")


if __name__ == "__main__":
    main()
