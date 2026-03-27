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

upstream boutique {
    server frontend:8080;
}

server {
    listen 80 default_server;
    server_name _;

    location = /healthz {
        access_log off;
        return 200;
    }

    return 404;
}

server {
    listen 80;
    server_name ${arcadia_domain};

    location = /healthz {
        access_log off;
        return 200;
    }

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

    location = /healthz {
        access_log off;
        return 200;
    }

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://dvwa/;
    }
}

server {
    listen 80;
    server_name ${boutique_domain};

    location = /healthz {
        access_log off;
        return 200;
    }

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://boutique/;
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
docker run -dit --restart unless-stopped -h redis-cart --name redis-cart --net internal redis:alpine
docker run -dit --restart unless-stopped -h emailservice --name emailservice --net internal -e PORT=8080 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/emailservice:v0.8.0
docker run -dit --restart unless-stopped -h paymentservice --name paymentservice --net internal -e PORT=50051 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/paymentservice:v0.8.0
docker run -dit --restart unless-stopped -h productcatalogservice --name productcatalogservice --net internal -e PORT=3550 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/productcatalogservice:v0.8.0
docker run -dit --restart unless-stopped -h currencyservice --name currencyservice --net internal -e PORT=7000 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/currencyservice:v0.8.0
docker run -dit --restart unless-stopped -h shippingservice --name shippingservice --net internal -e PORT=50051 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/shippingservice:v0.8.0
docker run -dit --restart unless-stopped -h cartservice --name cartservice --net internal -e REDIS_ADDR=redis-cart:6379 gcr.io/google-samples/microservices-demo/cartservice:v0.8.0
docker run -dit --restart unless-stopped -h recommendationservice --name recommendationservice --net internal -e PORT=8080 -e PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550 -e DISABLE_PROFILER=1 gcr.io/google-samples/microservices-demo/recommendationservice:v0.8.0
docker run -dit --restart unless-stopped -h adservice --name adservice --net internal -e PORT=9555 gcr.io/google-samples/microservices-demo/adservice:v0.8.0
docker run -dit --restart unless-stopped -h checkoutservice --name checkoutservice --net internal \
    -e PORT=5050 \
    -e PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550 \
    -e SHIPPING_SERVICE_ADDR=shippingservice:50051 \
    -e PAYMENT_SERVICE_ADDR=paymentservice:50051 \
    -e EMAIL_SERVICE_ADDR=emailservice:5000 \
    -e CURRENCY_SERVICE_ADDR=currencyservice:7000 \
    -e CART_SERVICE_ADDR=cartservice:7070 \
    gcr.io/google-samples/microservices-demo/checkoutservice:v0.8.0
docker run -dit --restart unless-stopped -h frontend --name frontend --net internal \
    -e PORT=8080 \
    -e PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550 \
    -e CURRENCY_SERVICE_ADDR=currencyservice:7000 \
    -e CART_SERVICE_ADDR=cartservice:7070 \
    -e RECOMMENDATION_SERVICE_ADDR=recommendationservice:8080 \
    -e SHIPPING_SERVICE_ADDR=shippingservice:50051 \
    -e CHECKOUT_SERVICE_ADDR=checkoutservice:5050 \
    -e AD_SERVICE_ADDR=adservice:9555 \
    -e ENABLE_PROFILER=0 \
    gcr.io/google-samples/microservices-demo/frontend:v0.8.0
docker run -dit --restart unless-stopped -h nginx --name nginx --net internal -p 8080:80 \
  -v /home/ec2-user/default.conf:/etc/nginx/conf.d/default.conf \
  registry.gitlab.com/arcadia-application/nginx/nginxoss:latest
