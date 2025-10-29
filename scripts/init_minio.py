#!/usr/bin/env python3
"""
Initialize MinIO with buckets and upload CSV datasets.
This script creates an S3 bucket and uploads all CSV files from the dataset directory.
"""
import os
import sys
import time
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("Error: boto3 is required. Install with: pip install boto3", file=sys.stderr)
    sys.exit(1)


def wait_for_minio(s3_client, max_retries=30, delay=2):
    """Wait for MinIO to be ready."""
    print("Waiting for MinIO to be ready...")
    for i in range(max_retries):
        try:
            s3_client.list_buckets()
            print("✓ MinIO is ready!")
            return True
        except Exception as e:
            if i < max_retries - 1:
                print(f"  Attempt {i+1}/{max_retries}: MinIO not ready yet, waiting {delay}s...")
                time.sleep(delay)
            else:
                print(f"✗ Failed to connect to MinIO after {max_retries} attempts", file=sys.stderr)
                print(f"  Error: {e}", file=sys.stderr)
                return False
    return False


def create_bucket_if_not_exists(s3_client, bucket_name):
    """Create an S3 bucket if it doesn't exist."""
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"  Bucket '{bucket_name}' already exists")
        return True
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == '404':
            # Bucket doesn't exist, create it
            try:
                s3_client.create_bucket(Bucket=bucket_name)
                print(f"✓ Created bucket '{bucket_name}'")
                return True
            except ClientError as create_error:
                print(f"✗ Failed to create bucket '{bucket_name}': {create_error}", file=sys.stderr)
                return False
        else:
            print(f"✗ Error checking bucket '{bucket_name}': {e}", file=sys.stderr)
            return False


def upload_file(s3_client, file_path, bucket_name, object_name=None):
    """Upload a file to an S3 bucket."""
    if object_name is None:
        object_name = file_path.name
    
    try:
        s3_client.upload_file(str(file_path), bucket_name, object_name)
        print(f"  ✓ Uploaded: {object_name} ({file_path.stat().st_size / 1024:.1f} KB)")
        return True
    except ClientError as e:
        print(f"  ✗ Failed to upload {object_name}: {e}", file=sys.stderr)
        return False


def upload_directory(s3_client, directory_path, bucket_name, prefix=""):
    """Upload all files from a directory to an S3 bucket."""
    directory = Path(directory_path)
    if not directory.exists() or not directory.is_dir():
        print(f"✗ Directory not found: {directory_path}", file=sys.stderr)
        return False
    
    files = list(directory.glob("*"))
    files = [f for f in files if f.is_file()]
    
    if not files:
        print(f"  No files found in {directory_path}")
        return True
    
    print(f"\nUploading {len(files)} file(s) from {directory_path}...")
    success_count = 0
    for file_path in sorted(files):
        object_name = f"{prefix}{file_path.name}" if prefix else file_path.name
        if upload_file(s3_client, file_path, bucket_name, object_name):
            success_count += 1
    
    print(f"  Uploaded {success_count}/{len(files)} files successfully")
    return success_count == len(files)


def set_bucket_policy(s3_client, bucket_name, policy="read"):
    """Set bucket policy to allow anonymous read access."""
    if policy == "read":
        bucket_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:GetObject"],
                    "Resource": [f"arn:aws:s3:::{bucket_name}/*"]
                },
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": ["*"]},
                    "Action": ["s3:ListBucket"],
                    "Resource": [f"arn:aws:s3:::{bucket_name}"]
                }
            ]
        }
        try:
            import json
            s3_client.put_bucket_policy(
                Bucket=bucket_name,
                Policy=json.dumps(bucket_policy)
            )
            print(f"  ✓ Set public read policy on bucket '{bucket_name}' (anonymous access enabled)")
            return True
        except ClientError as e:
            print(f"  ⚠ Warning: Could not set bucket policy: {e}")
            return False
    return True


def main():
    # Configuration
    MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
    MINIO_ACCESS_KEY = os.getenv("MINIO_ROOT_USER", "admin")
    MINIO_SECRET_KEY = os.getenv("MINIO_ROOT_PASSWORD", "")
    
    if not MINIO_SECRET_KEY:
        print("Error: MINIO_ROOT_PASSWORD environment variable not set", file=sys.stderr)
        sys.exit(1)
    
    # Paths
    script_dir = Path(__file__).resolve().parent
    root_dir = script_dir.parent
    csv_dir = root_dir / "dataset" / "csv"
    
    print("=" * 60)
    print("MinIO S3 Initialization Script")
    print("=" * 60)
    print(f"MinIO Endpoint: {MINIO_ENDPOINT}")
    print(f"Access Key: {MINIO_ACCESS_KEY}")
    print(f"CSV Directory: {csv_dir}")
    print("=" * 60)
    
    # Create S3 client
    s3_client = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        region_name='us-east-1'
    )
    
    # Wait for MinIO to be ready
    if not wait_for_minio(s3_client):
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("Creating buckets and uploading datasets...")
    print("=" * 60)
    
    # Create workshop-data bucket
    bucket_name = "workshop-data"
    if not create_bucket_if_not_exists(s3_client, bucket_name):
        sys.exit(1)
    
    # Upload CSV files
    success = upload_directory(s3_client, csv_dir, bucket_name, prefix="csv/")
    
    # Set bucket policy for public read (enables anonymous access)
    print("\nConfiguring bucket for anonymous read access...")
    set_bucket_policy(s3_client, bucket_name, policy="read")
    
    print("\n" + "=" * 60)
    if success:
        print("✓ MinIO initialization completed successfully!")
        print(f"\nAccess your data:")
        print(f"  S3 API: {MINIO_ENDPOINT}")
        print(f"  Bucket: s3://{bucket_name}/ (PUBLIC READ ACCESS)")
        print(f"  CSV files: s3://{bucket_name}/csv/")
        print(f"\nExample usage in Python (NO CREDENTIALS NEEDED):")
        print(f"  import pandas as pd")
        print(f"  df = pd.read_csv('s3://{bucket_name}/csv/beers.csv',")
        print(f"                    storage_options={{'client_kwargs': {{'endpoint_url': '{MINIO_ENDPOINT}'}}}})")
        print(f"\nOr with boto3 (anonymous):")
        print(f"  import boto3")
        print(f"  from botocore import UNSIGNED")
        print(f"  from botocore.config import Config")
        print(f"  s3 = boto3.client('s3', endpoint_url='{MINIO_ENDPOINT}', config=Config(signature_version=UNSIGNED))")
        print(f"  s3.download_file('{bucket_name}', 'csv/beers.csv', 'local_beers.csv')")
    else:
        print("⚠ MinIO initialization completed with some errors")
        sys.exit(1)
    print("=" * 60)


if __name__ == "__main__":
    main()

