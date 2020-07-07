#!/bin/bash
# ソースを最新化
su -l airflow -c 'cd /home/airflow/;
git clone git@github.com:<gh_repository>.git;
mkdir -p /home/airflow/airflow_on_gcp/postgres_mnt;';

# postgresのデータを永続化するために、外部ディスクをマウント
mount -o discard,defaults /dev/sdb /home/airflow/airflow_on_gcp/postgres_mnt;
chmod a+w /home/airflow/airflow_on_gcp/postgres_mnt;
df -h;

# docker composeでairflowを立ち上げ
su -l airflow -c 'cd /home/airflow/airflow_on_gcp;
docker-credential-gcr configure-docker;
make up';
