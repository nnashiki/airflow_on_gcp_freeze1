#!/bin/bash

# ロギング エージェントのインストール
curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
bash install-logging-agent.sh

# モニタリング エージェントのインストール
curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
sudo bash install-monitoring-agent.sh

# apt
export DEBIAN_FRONTEND=noninteractive

apt update
yes '' | apt -y -o DPkg::options::="--force-confdef" \
    -o DPkg::options::="--force-confold" upgrade
yes '' | apt -y -o DPkg::options::="--force-confdef" \
    -o DPkg::options::="--force-confold" install docker-compose build-essential
# build-essential: GNU make を取得

# docker groupを生成
groupadd docker

# app 実行ユーザの作成
users=("airflow")
for username in $users; do
adduser --disabled-password --gecos "" "$username"
echo "${username}:${username}" | chpasswd
gpasswd -a "$username" sudo

# dockerを実行させるためのグループに追加
usermod -aG docker $username
done

# Standalone Docker credential helper
VERSION=2.0.0
OS=linux  # or "darwin" for OSX, "windows" for Windows.
ARCH=amd64  # or "386" for 32-bit OSs, "arm64" for ARM 64.
curl -fsSL "https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v${VERSION}/docker-credential-gcr_${OS}_${ARCH}-${VERSION}.tar.gz" \
| tar xz --to-stdout ./docker-credential-gcr \
> /usr/local/bin/docker-credential-gcr && chmod +x /usr/local/bin/docker-credential-gcr
