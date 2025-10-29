# Workshop Data Architecture Stack

A complete data workshop environment with JupyterHub, Spark, MySQL, Redis, Qdrant, MinIO (S3), and Vespa.

## Quick Start

```bash
# 1. Generate user credentials
make generate-users

# 2. Start all services
make up

# 3. Initialize MinIO S3 buckets with datasets
make init-minio

# 4. Access JupyterHub
open http://localhost:8000
```

## Services

| Service | Port(s) | Purpose | URL |
|---------|---------|---------|-----|
| **JupyterHub** | 8000 | Multi-user Jupyter notebooks | http://localhost:8000 |
| **MySQL** | 3306 | Relational database | localhost:3306 |
| **Redis** | 6379 | Key-value store & cache | localhost:6379 |
| **Qdrant** | 6333, 6334 | Vector database | http://localhost:6333 |
| **MinIO** | 9000, 9001 | S3-compatible object storage | http://localhost:9001 (console) |
| **Vespa** | 8080, 19071, 19050 | Search engine | http://localhost:8080 |
| **Spark Master** | 7077, 8082 | Distributed computing | http://localhost:8082 (UI) |
| **Spark Worker** | 8081 | Spark worker node | http://localhost:8081 (UI) |

## Setup Instructions

### 1. User Management

Edit student names and generate credentials:

```bash
# Edit students list
nano jupyterhub/users/students.txt

# Generate credentials (creates users.csv, allowlist.txt, admins.txt)
make generate-users
```

See [README_USERS.md](README_USERS.md) for details.

### 2. Admin Password

The admin password is stored in `jupyterhub/admin.password` (git-ignored):

```bash
# Edit admin password
nano jupyterhub/admin.password
```

### 3. Environment Configuration

Service credentials are in `workshop.env`:

```env
MYSQL_ROOT_PASSWORD=dsjfbf342qD
REDIS_PASSWORD=QEFER1sd2
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=qdsd23SDD2
```

### 4. Datasets

Datasets are available in two ways:

#### A. Direct File Access (Read-Only)

All datasets mounted at `/datasets/` in JupyterHub:

```python
import pandas as pd
df = pd.read_csv('/datasets/csv/beers.csv')
```

#### B. S3 Access via MinIO (Anonymous - No Credentials!)

Initialize MinIO buckets:

```bash
make init-minio
```

After initialization, the bucket is configured for anonymous read access:

```python
import pandas as pd

# Read directly from S3 - NO CREDENTIALS NEEDED!
df = pd.read_csv(
    's3://workshop-data/csv/beers.csv',
    storage_options={
        'client_kwargs': {
            'endpoint_url': 'http://minio:9000'
        }
    }
)
```

Or with boto3 (anonymous):

```python
import boto3
from botocore import UNSIGNED
from botocore.config import Config
from io import BytesIO
import pandas as pd

s3 = boto3.client(
    's3',
    endpoint_url='http://minio:9000',
    config=Config(signature_version=UNSIGNED)
)

obj = s3.get_object(Bucket='workshop-data', Key='csv/beers.csv')
df = pd.read_csv(BytesIO(obj['Body'].read()))
```

See:
- [minio/README.md](minio/README.md) for S3 setup details
- [work/Example_S3_Access.ipynb](work/Example_S3_Access.ipynb) for usage examples

## Available Datasets

Located in `dataset/` and accessible via:
- File path: `/datasets/`
- S3 bucket: `s3://workshop-data/csv/`

### CSV Files

- `categories.csv` - Beer categories (~500 B)
- `styles.csv` - Beer styles (~8 KB)
- `breweries.csv` - Brewery information (~329 KB)
- `breweries_geocode.csv` - Brewery geocodes (~61 KB)
- `beers.csv` - Beer details (~1.2 MB)

### SQL Files

SQL dumps for MySQL initialization in `dataset/sql/`

### Other Formats

- `dataset/cliclog/` - Click log interaction data
- `dataset/vespa/` - Vespa search engine data (JSONL)

## Common Commands

```bash
# Start services
make up                 # Start all services in background
make start              # Start existing containers
make ps                 # Show service status

# Stop services
make stop               # Stop containers (keep data)
make down               # Stop and remove containers (keep volumes)

# Logs
make logs               # View all service logs
make logs-hub           # View JupyterHub logs only

# Rebuild
make build              # Rebuild all images
make rebuild-hub        # Rebuild only JupyterHub

# Data management
make init-minio         # Initialize MinIO S3 buckets
make generate-users     # Generate user credentials

# Cleanup
make clean              # Remove containers AND volumes (⚠️ DATA LOSS)
make purge-homes        # Remove user home directories (⚠️ DATA LOSS)
```

## Data Persistence

The following data persists across container restarts:

- **User home directories**: Docker volume `jupyterhub-homes`
- **MySQL data**: `./mysql/data/`
- **MinIO data**: `./minio/data/`
- **Redis data**: `./redis/data/`
- **Qdrant storage**: `./qdrant/storage/`
- **Vespa data**: `./vespa/var/`
- **Spark state**: `./spark/`
- **Shared workspace**: `./work/`

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     workshop-net                            │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐             │
│  │  JupyterHub  │  │  MySQL   │  │  Redis   │             │
│  │  (port 8000) │  │ (3306)   │  │ (6379)   │             │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘             │
│         │               │             │                     │
│  ┌──────▼────────────────▼─────────────▼─────┐             │
│  │           Shared Network Layer            │             │
│  └──────┬────────────────┬─────────────┬─────┘             │
│         │                │             │                     │
│  ┌──────▼───────┐  ┌────▼─────┐  ┌───▼──────┐             │
│  │    MinIO     │  │  Qdrant  │  │  Vespa   │             │
│  │  (S3 9000)   │  │  (6333)  │  │  (8080)  │             │
│  └──────────────┘  └──────────┘  └──────────┘             │
│                                                              │
│  ┌──────────────┐  ┌──────────────────────────┐            │
│  │ Spark Master │──│   Spark Worker(s)        │            │
│  │  (7077)      │  │      (8081)              │            │
│  └──────────────┘  └──────────────────────────┘            │
└────────────────────────────────────────────────────────────┘
         │                    │                    │
    ┌────▼────┐          ┌───▼────┐          ┌───▼────┐
    │ Volumes │          │ Mounts │          │ Datasets│
    └─────────┘          └────────┘          └─────────┘
```

## User Access

### For Students

1. Log in to JupyterHub: http://localhost:8000
2. Use credentials from `jupyterhub/users/users.csv`
3. Find datasets at `/datasets/` or via S3
4. Check `~/README_DATASETS.txt` for dataset information
5. Use `/work/` for shared notebooks

### For Admins

- Admin username: `admin`
- Admin password: Set in `jupyterhub/admin.password`
- Admin users listed in `jupyterhub/users/admins.txt`
- Access all services via their respective UIs/ports

## Troubleshooting

### Services won't start

```bash
# Check service status
make ps

# Check logs for errors
make logs

# Restart everything
make down && make up
```

### Out of disk space

```bash
# Check Docker disk usage
docker system df

# Clean up old containers/images
docker system prune

# Remove workshop volumes (⚠️ DATA LOSS)
make clean
```

### MinIO S3 not accessible

```bash
# Reinitialize MinIO
make init-minio

# Check MinIO logs
docker logs minio
```

### User can't log in

```bash
# Regenerate user credentials
make generate-users

# Rebuild and restart JupyterHub
make rebuild-hub
```

## Development

### Adding New Services

1. Add service to `docker-compose.yml`
2. Connect to `workshop-net` network
3. Add any required volumes
4. Update this README

### Modifying JupyterHub

```bash
# Edit configuration
nano jupyterhub/jupyterhub_config.py

# Edit startup script
nano jupyterhub/start.sh

# Rebuild and restart
make rebuild-hub
```

## Requirements

- Docker and Docker Compose
- Python 3.7+ (for management scripts)
- `boto3` Python package (for MinIO initialization)

## License

Workshop environment for educational purposes.

## See Also

- [README_USERS.md](README_USERS.md) - User management details
- [minio/README.md](minio/README.md) - MinIO S3 setup
- [work/Example_S3_Access.ipynb](work/Example_S3_Access.ipynb) - S3 access examples

