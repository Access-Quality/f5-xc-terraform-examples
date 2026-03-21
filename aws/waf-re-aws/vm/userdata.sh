#!/bin/bash
set -ex

# Docker installation (Amazon Linux 2)
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Create nginx reverse proxy config
sudo touch /home/ec2-user/default.conf

sudo tee /home/ec2-user/default.conf > /dev/null << 'NGINXCONF'
upstream mainapp {
        server mainapp;
}

upstream backend {
        server backend;
}

upstream app2 {
        server app2;
}

upstream app3 {
        server app3;
}

server {

    listen       80 default_server;

    location / {
        proxy_pass http://mainapp/;
    }

    location /files {
        proxy_pass http://backend/files/;
    }

    location /api {
        proxy_pass http://app2/api/;
    }

    location /app3 {
        proxy_pass http://app3/app3/;
    }

    error_page   500 502 503 504  /50x.html;

    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
NGINXCONF

# Deploy Arcadia Finance containers
docker network create internal
docker run -dit -h mainapp --name=mainapp --net=internal registry.gitlab.com/arcadia-application/main-app/mainapp:latest
docker run -dit -h backend --name=backend --net=internal registry.gitlab.com/arcadia-application/back-end/backend:latest
docker run -dit -h app2 --name=app2 --net=internal registry.gitlab.com/arcadia-application/app2/app2:latest
docker run -dit -h app3 --name=app3 --net=internal registry.gitlab.com/arcadia-application/app3/app3:latest
docker run -dit -h nginx --name=nginx --net=internal -p 8080:80 \
  -v /home/ec2-user/default.conf:/etc/nginx/conf.d/default.conf \
  registry.gitlab.com/arcadia-application/nginx/nginxoss:latest
