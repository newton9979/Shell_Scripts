#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========== Docker Installation Started =========="

apt update -y

if ! command -v docker >/dev/null 2>&1; then
    apt install docker.io -y
fi

systemctl enable docker
systemctl start docker

if systemctl is-active --quiet docker; then
    echo "Docker Service Started Successfully"
else
    echo "Docker Service Failed"
    exit 1
fi

usermod -aG docker ubuntu

docker --version

docker ps

echo "========== Docker Installation Completed =========="
