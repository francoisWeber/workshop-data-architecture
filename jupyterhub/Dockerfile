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

# Install Hadoop AWS JARs for S3 access in PySpark
COPY install_s3_jars.py /tmp/install_s3_jars.py
RUN python3 /tmp/install_s3_jars.py && rm /tmp/install_s3_jars.py

COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8000

CMD ["/usr/local/bin/start.sh"]
