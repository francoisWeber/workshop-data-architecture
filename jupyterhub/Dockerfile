FROM jupyterhub/jupyterhub:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    adduser \
    passwd \
    openjdk-17-jre-headless \
  && rm -rf /var/lib/apt/lists/*

# Install JupyterLab and common data science packages
RUN python3 -m pip install --no-cache-dir \
    jupyterlab \
    notebook \
    ipywidgets \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    pyspark \
    pymysql \
    redis \
    boto3 \
    qdrant-client \
    fsspec s3fs

COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8000

CMD ["/usr/local/bin/start.sh"]
