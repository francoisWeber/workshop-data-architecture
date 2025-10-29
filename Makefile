# Variables (override with: make VAR=value)
JUPYTER_IMAGE ?= jupyter/pyspark-notebook:latest
ADMINS ?= admin
STUDENTS ?= jupyterhub/users/students.txt

.PHONY: help up down start stop restart build rebuild-hub logs logs-hub ps pull generate-users pull-notebook clean purge-homes init-minio init-shared s3-ls

help:
	@echo "Common targets:"
	@echo "  up               - Start all services in background"
	@echo "  down             - Stop and remove containers (keep volumes)"
	@echo "  start            - Start already created containers"
	@echo "  stop             - Stop running containers"
	@echo "  restart          - Restart all services"
	@echo "  build            - Build all images"
	@echo "  rebuild-hub      - Rebuild JupyterHub image and restart only hub"
	@echo "  logs             - Tail all service logs"
	@echo "  logs-hub         - Tail JupyterHub logs"
	@echo "  ps               - Show compose status"
	@echo "  pull             - Pull latest images"
	@echo "  pull-notebook    - Pre-pull single-user notebook image ($(JUPYTER_IMAGE))"
	@echo "  generate-users   - Generate users.csv, allowlist, admins from $(STUDENTS)"
	@echo "  init-minio       - Initialize MinIO buckets and upload CSV datasets"
	@echo "  init-shared      - Initialize shared directory volume (first-time setup)"
	@echo "  s3-ls            - List files in MinIO S3 bucket"
	@echo "  clean            - Stop and remove containers AND volumes (DATA LOSS)"
	@echo "  purge-homes      - Remove JupyterHub user home directories volume (DATA LOSS)"

up:
	docker compose up -d

down:
	docker compose down

start:
	docker compose start

stop:
	docker compose stop

restart:
	docker compose restart

build:
	docker compose build

rebuild-hub:
	docker compose build jupyterhub && docker compose up -d jupyterhub

logs:
	docker compose logs -f --tail=200

logs-hub:
	docker compose logs -f jupyterhub

ps:
	docker compose ps

pull:
	docker compose pull

pull-notebook:
	docker pull $(JUPYTER_IMAGE)

generate-users:
	python3 scripts/generate_user_credentials.py --students "$(STUDENTS)" --admins "$(ADMINS)"

init-minio:
	@echo "Initializing MinIO S3 buckets..."
	@export $$(cat workshop.env | grep -v '^#' | xargs) && \
	MINIO_ENDPOINT=http://localhost:9000 python3 scripts/init_minio.py

init-shared:
	@echo "Initializing shared directory volume..."
	@bash scripts/init_shared.sh

s3-ls:
	@echo "Listing S3 bucket contents..."
	@docker exec -it minio mc ls --recursive local/workshop-data/ 2>/dev/null || \
		echo "MinIO container not running. Start with 'make up' first."

clean:
	docker compose down -v

purge-homes:
	@echo "WARNING: This will delete all user home directories!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down jupyterhub && \
		docker volume rm jupyterhub-homes || true; \
		echo "User home directories volume purged."; \
	else \
		echo "Cancelled."; \
	fi
