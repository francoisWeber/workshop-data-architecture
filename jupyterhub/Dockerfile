FROM jupyterhub/jupyterhub:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    adduser \
    passwd \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir \
    dockerspawner

COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8000

CMD ["/usr/local/bin/start.sh"]
