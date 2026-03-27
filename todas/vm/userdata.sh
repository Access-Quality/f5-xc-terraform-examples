#!/bin/bash
set -ex

# Docker installation (Amazon Linux 2)
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Create nginx reverse proxy config for both applications
sudo tee /home/ec2-user/default.conf > /dev/null <<'NGINXCONF'
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

upstream dvwa {
    server dvwa;
}

server {
    listen 80 default_server;
    server_name _;
    return 404;
}

server {
    listen 80;
    server_name ${arcadia_domain};

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://mainapp/;
    }

    location /files {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://backend/files/;
    }

    location /api {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://app2/api/;
    }

    location /app3 {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://app3/app3/;
    }
}

server {
    listen 80;
    server_name ${dvwa_domain};

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://dvwa/;
    }
}
NGINXCONF

# Deploy application containers
docker network inspect internal >/dev/null 2>&1 || docker network create internal
docker run -dit --restart unless-stopped -h mainapp --name mainapp --net internal registry.gitlab.com/arcadia-application/main-app/mainapp:latest
docker run -dit --restart unless-stopped -h backend --name backend --net internal registry.gitlab.com/arcadia-application/back-end/backend:latest
docker run -dit --restart unless-stopped -h app2 --name app2 --net internal registry.gitlab.com/arcadia-application/app2/app2:latest
docker run -dit --restart unless-stopped -h app3 --name app3 --net internal registry.gitlab.com/arcadia-application/app3/app3:latest
docker run -dit --restart unless-stopped -h dvwa --name dvwa --net internal vulnerables/web-dvwa
docker run -dit --restart unless-stopped -h nginx --name nginx --net internal -p 8080:80 \
  -v /home/ec2-user/default.conf:/etc/nginx/conf.d/default.conf \
  registry.gitlab.com/arcadia-application/nginx/nginxoss:latest
