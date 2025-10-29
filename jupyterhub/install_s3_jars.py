#!/usr/bin/env python3
"""Download Hadoop AWS JARs for PySpark S3 support."""
import os
import urllib.request
import pyspark

# Find Spark installation
spark_home = os.path.dirname(pyspark.__file__)
jars_dir = os.path.join(spark_home, 'jars')

# JAR versions (matched to PySpark 4.0.1 / Hadoop 3.4.x)
# Hadoop 3.4.0 uses AWS SDK v2
hadoop_version = '3.4.0'
aws_sdk_version = '2.28.11'  # AWS SDK v2
base_url = 'https://repo1.maven.org/maven2'

# JARs to download (AWS SDK v2 bundle)
jars = [
    (f'{base_url}/org/apache/hadoop/hadoop-aws/{hadoop_version}/hadoop-aws-{hadoop_version}.jar', 'hadoop-aws'),
    (f'{base_url}/software/amazon/awssdk/bundle/{aws_sdk_version}/bundle-{aws_sdk_version}.jar', 'aws-sdk-v2'),
    (f'{base_url}/software/amazon/awssdk/url-connection-client/{aws_sdk_version}/url-connection-client-{aws_sdk_version}.jar', 'aws-url-connection'),
]

print('Downloading Hadoop AWS JARs for S3 support (AWS SDK v2)...')
for url, name in jars:
    filename = os.path.basename(url)
    filepath = os.path.join(jars_dir, filename)
    print(f'  Downloading {name}...')
    urllib.request.urlretrieve(url, filepath)
    print(f'    ✓ {filename}')

print('✓ Hadoop AWS JARs installed successfully (AWS SDK v2)')

