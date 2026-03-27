#!/bin/bash
set -ex

sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

sudo tee /home/ec2-user/crapi-jwks.json > /dev/null <<'JWKS'
{
    "keys": [
        {
            "p": "-o_gG3DQK9540fR_-WM9dy1YgTR-WSH8FezYnH6I5jwwPB6ocni8XgkWCAiKOPYjK6nhmoTD7DBEetilFIWVj1P0G5fejp_c3H-uQQdd6JW2NBWHfWpADglIEc4NfUgjQ8cXjT1-oIJpXzpX6KOhWEP0yGNBYns7W8CNxbw58vU",
            "kty": "RSA",
            "q": "tW1D1JK53TIiip9uBVl6EGzXWPFwy8QXlZHbfg3TfhURUF5OYey9Ig-qxh74KvQ-uzwMZOYux0EdUe0OmV-p27huY-nusHjpxKL6xUxpqsLWrYTa6ygRHep3_A50ksN_XIn83oAjBlG4TEePzBsMQb6F4HDrEhpdPeYepKa5PNc",
            "d": "XJu0Vh3Uq5gV5UPMCfm_j6D5INgX7VjLSN8mup4LfUBkJAk9vpQmDYF8gVzpMr3YdBk_Y7MI1BapPVg2i-s2UQR4xJYwpDOfKJactGWzruvfiTOKNIc8Q87WhLl2D4_FGI2jfyYk6itCLOOk1zfZdkjLLNiQg1SDOqC28AT-qKh99wLRKiIuewbJVW5C-0D8YjlquBU6rXdKxONYKnA1NHWfJEbPtsyJIlfUs06wjiMcXrLLc6qy98LL8t0oQcGdUTN4rICGGj-uH3k7-evJyKXC_RECmbcMu2q8GkjZ7lvaVtHh3TGGAA5TTc-7kW3MUjpCLLL06erLxCn3CcGr6Q",
            "e": "AQAB",
            "use": "sig",
            "kid": "MKMZkDenUfuDF2byYowDj7tW5Ox6XG4Y1THTEGScRg8",
            "qi": "IChXZG2VaA05LVfN-nIX03sAZo7ayetTiFKrhGpdmsODw9AoCbBIx4T4SuPnQQBYVkaCAcseyB1XAjqA4Ebm2yvE6yYo-Q8nP-wEo5Mzm18UimCffMox-uSrig1uhuK9oziV-Y11Ytps8yEQq--9BzVTCs1sXAkLVSaO58kGsm4",
            "dp": "rl98fnxXU4BjIvJ-MWfAOfVj159ZotxE3FlVMivZSClxBBXt8qRVqze1jmerEhMxzMxQRkHJO9EnhzrIP-zrdbDefGmHqEhW41k0QutGjnvKLpshDMXpyBrrfgChYKPYbu3aVSALxNadUHmA_lUKDyxT6TUyJsBOQf9Sat8gkRU",
            "alg": "RS256",
            "dq": "d8mf-o-yJmj-w3ZGh0Ovw36JpREs_20GgVvfh1gLpvi0CNNrf1529jFP-SXjh0Di1m7sZAZTJn5IpJoXhI7UMN2SDWgcj-oVtx5A4tnz_qpMYh8RCCjZPF5eQE8vCuQHiIsXKbWC6p40SDELsaC-M_5emHUV0EsV-1OgMehe79s",
            "n": "sZKrGYja9S7BkO-waOcupoGY6BQjixJkg1Uitt278NbiCSnBRw5_cmfuWFFFPgRxabBZBJwJAujnQrlgTLXnRRItM9SRO884cEXn-s4Uc8qwk6pev63qb8no6aCVY0dFpthEGtOP-3KIJ2kx2i5HNzm8d7fG3ZswZrttDVbSSTy8UjPTOr4xVw1Yyh_GzGK9i_RYBWHftDsVfKrHcgGn1F_T6W0cgcnh4KFmbyOQ7dUy8Uc6Gu8JHeHJVt2vGcn50EDtUy2YN-UnZPjCSC7vYOfd5teUR_Bf4jg8GN6UnLbr_Et8HUnz9RFBLkPIf0NiY6iRjp9ooSDkml2OGql3ww"
        }
    ]
}
JWKS

docker network inspect internal >/dev/null 2>&1 || docker network create internal
docker volume inspect crapi-postgres-data >/dev/null 2>&1 || docker volume create crapi-postgres-data
docker volume inspect crapi-mongodb-data >/dev/null 2>&1 || docker volume create crapi-mongodb-data

docker run -dit --restart unless-stopped -h mainapp --name mainapp --net internal -p 18080:80 registry.gitlab.com/arcadia-application/main-app/mainapp:latest
docker run -dit --restart unless-stopped -h backend --name backend --net internal -p 18081:80 registry.gitlab.com/arcadia-application/back-end/backend:latest
docker run -dit --restart unless-stopped -h app2 --name app2 --net internal -p 18082:80 registry.gitlab.com/arcadia-application/app2/app2:latest
docker run -dit --restart unless-stopped -h app3 --name app3 --net internal -p 18083:80 registry.gitlab.com/arcadia-application/app3/app3:latest
docker run -dit --restart unless-stopped -h dvwa --name dvwa --net internal -p 18084:80 vulnerables/web-dvwa
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
    -p 18085:8080 \
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

docker run -dit --restart unless-stopped -h postgresdb --name postgresdb --net internal \
    -e POSTGRES_USER=admin \
    -e POSTGRES_PASSWORD=crapisecretpassword \
    -e POSTGRES_DB=crapi \
    -v crapi-postgres-data:/var/lib/postgresql/data \
    postgres:14
docker run -dit --restart unless-stopped -h mongodb --name mongodb --net internal \
    -e MONGO_INITDB_ROOT_USERNAME=admin \
    -e MONGO_INITDB_ROOT_PASSWORD=crapisecretpassword \
    -v crapi-mongodb-data:/data/db \
    mongo:5.0
docker run -dit --restart unless-stopped -h mailhog --name mailhog --net internal --network-alias mailhog-web \
    -p 18087:8025 \
    -e MH_MONGO_URI=admin:crapisecretpassword@mongodb:27017 \
    -e MH_STORAGE=mongodb \
    crapi/mailhog:latest
docker run -dit --restart unless-stopped -h gateway-service --name gateway-service --net internal \
    -e SERVER_PORT=443 \
    crapi/gateway-service:develop

sleep 20

docker run -dit --restart unless-stopped -h crapi-identity --name crapi-identity --net internal \
    -e LOG_LEVEL=INFO \
    -e DB_HOST=postgresdb \
    -e DB_DRIVER=postgresql \
    -e JWT_SECRET=crapi \
    -e DB_USER=admin \
    -e DB_PASSWORD=crapisecretpassword \
    -e DB_NAME=crapi \
    -e DB_PORT=5432 \
    -e APP_NAME=crapi-identity \
    -e ENABLE_SHELL_INJECTION=false \
    -e ENABLE_LOG4J=true \
    -e MAILHOG_HOST=mailhog \
    -e MAILHOG_PORT=1025 \
    -e MAILHOG_DOMAIN=example.com \
    -e SMTP_HOST=smtp.example.com \
    -e SMTP_PORT=587 \
    -e SMTP_EMAIL=user@example.com \
    -e SMTP_PASS=xxxxxxxxxxxxxx \
    -e SMTP_FROM=no-reply@example.com \
    -e SMTP_AUTH=true \
    -e JWT_EXPIRATION=604800000 \
    -e SMTP_STARTTLS=true \
    -e SERVER_PORT=8080 \
    -e API_GATEWAY_URL=https://gateway-service \
    -e TLS_ENABLED=false \
    -e TLS_KEYSTORE_TYPE=PKCS12 \
    -e TLS_KEYSTORE=classpath:certs/server.p12 \
    -e TLS_KEYSTORE_PASSWORD=passw0rd \
    -e TLS_KEY_PASSWORD=passw0rd \
    -e TLS_KEY_ALIAS=identity \
    -v /home/ec2-user/crapi-jwks.json:/.keys/jwks.json:ro \
    crapi/crapi-identity:develop

sleep 10

docker run -dit --restart unless-stopped -h crapi-community --name crapi-community --net internal \
    -e LOG_LEVEL=INFO \
    -e IDENTITY_SERVICE=crapi-identity:8080 \
    -e DB_HOST=postgresdb \
    -e DB_DRIVER=postgres \
    -e DB_USER=admin \
    -e DB_PASSWORD=crapisecretpassword \
    -e DB_NAME=crapi \
    -e DB_PORT=5432 \
    -e MONGO_DB_HOST=mongodb \
    -e MONGO_DB_DRIVER=mongodb \
    -e MONGO_DB_USER=admin \
    -e MONGO_DB_PASSWORD=crapisecretpassword \
    -e MONGO_DB_NAME=crapi \
    -e MONGO_DB_PORT=27017 \
    -e SERVER_PORT=8087 \
    -e TLS_ENABLED=false \
    crapi/crapi-community:develop
docker run -dit --restart unless-stopped -h crapi-workshop --name crapi-workshop --net internal \
    -e LOG_LEVEL=INFO \
    -e IDENTITY_SERVICE=crapi-identity:8080 \
    -e SECRET_KEY=crapi \
    -e DB_HOST=postgresdb \
    -e DB_DRIVER=postgres \
    -e DB_USER=admin \
    -e DB_PASSWORD=crapisecretpassword \
    -e DB_NAME=crapi \
    -e DB_PORT=5432 \
    -e MONGO_DB_HOST=mongodb \
    -e MONGO_DB_DRIVER=mongodb \
    -e MONGO_DB_PORT=27017 \
    -e MONGO_DB_USER=admin \
    -e MONGO_DB_PASSWORD=crapisecretpassword \
    -e MONGO_DB_NAME=crapi \
    -e SERVER_PORT=8000 \
    -e API_GATEWAY_URL=https://gateway-service \
    -e TLS_ENABLED=false \
    crapi/crapi-workshop:develop

sleep 15

docker run -dit --restart unless-stopped -h crapi-web --name crapi-web --net internal \
    -p 18086:80 \
    -e COMMUNITY_SERVICE=crapi-community:8087 \
    -e IDENTITY_SERVICE=crapi-identity:8080 \
    -e WORKSHOP_SERVICE=crapi-workshop:8000 \
    -e MAILHOG_WEB_SERVICE=mailhog-web:8025 \
    -e TLS_ENABLED=false \
    -e CHATBOT_SERVICE=localhost:9999 \
    crapi/crapi-web:develop