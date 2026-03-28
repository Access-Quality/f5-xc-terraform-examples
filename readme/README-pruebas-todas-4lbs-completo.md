# Pruebas de seguridad y validacion funcional para el caso AWS compartido con 4 LBs XC

Esta guia describe pruebas mas completas para el escenario documentado en `readme/README-sec-re-aws-todas-4lbs-apply.md`.

Aplica al caso donde:

- una sola VM en AWS aloja Arcadia, DVWA, Boutique, crAPI y Mailhog
- no hay nginx en la VM
- F5 XC publica 4 HTTP Load Balancers
- Mailhog comparte el mismo LB que crAPI

No debe usarse fuera de un entorno autorizado.

---

## 1. Objetivo

Validar en un mismo escenario:

- disponibilidad publica por dominio
- routing correcto por LB y por path
- comportamiento funcional minimo de cada aplicacion
- visibilidad de eventos WAF, API Discovery, API Protection y Bot Defense donde apliquen
- diagnostico rapido cuando falla una sola aplicacion dentro de la VM compartida

---

## 2. Mapa del caso

| Aplicacion | Dominio | LB esperado | Puerto origen |
| --- | --- | --- | --- |
| Arcadia | `ARCADIA_DOMAIN` | Arcadia | `18080` |
| Arcadia files | `ARCADIA_DOMAIN/files` | Arcadia | `18081` |
| Arcadia api | `ARCADIA_DOMAIN/api` | Arcadia | `18082` |
| Arcadia app3 | `ARCADIA_DOMAIN/app3` | Arcadia | `18083` |
| DVWA | `DVWA_DOMAIN` | DVWA | `18084` |
| Boutique | `BOUTIQUE_DOMAIN` | Boutique | `18085` |
| crAPI | `CRAPI_DOMAIN` | crAPI | `18086` |
| Mailhog | `MAILHOG_DOMAIN` | crAPI | `18087` |

Variables recomendadas:

```bash
export ARCADIA_DOMAIN="arcadia.digitalvs.com"
export DVWA_DOMAIN="dvwa.digitalvs.com"
export BOUTIQUE_DOMAIN="boutique.digitalvs.com"
export CRAPI_DOMAIN="crapi.digitalvs.com"
export MAILHOG_DOMAIN="mailhog.digitalvs.com"

export ARC_BASE="http://${ARCADIA_DOMAIN}"
export DVWA_BASE="http://${DVWA_DOMAIN}"
export BOUTIQUE_BASE="http://${BOUTIQUE_DOMAIN}"
export CRAPI_BASE="http://${CRAPI_DOMAIN}"
export MAILHOG_BASE="http://${MAILHOG_DOMAIN}"
export ARC_COOKIE="/tmp/arcadia_cookie.txt"
```

---

## 3. Validacion inicial de disponibilidad

### 3.1. Comprobacion basica por dominio

```bash
curl -s -o /dev/null -w "arcadia=%{http_code}\n" "${ARC_BASE}/"
curl -s -o /dev/null -w "dvwa=%{http_code}\n" "${DVWA_BASE}/"
curl -s -o /dev/null -w "boutique=%{http_code}\n" "${BOUTIQUE_BASE}/"
curl -s -o /dev/null -w "crapi=%{http_code}\n" "${CRAPI_BASE}/"
curl -s -o /dev/null -w "mailhog=%{http_code}\n" "${MAILHOG_BASE}/"
```

Esperado:

- Arcadia `200`
- DVWA `200`, `301` o `302`
- Boutique `200`
- crAPI `200`
- Mailhog `200`

### 3.2. Arcadia por rutas

```bash
curl -s -o /dev/null -w "/=%{http_code}\n" "${ARC_BASE}/"
curl -s -o /dev/null -w "/files=%{http_code}\n" "${ARC_BASE}/files/"
curl -s -o /dev/null -w "/api=%{http_code}\n" "${ARC_BASE}/api/"
curl -s -o /dev/null -w "/app3=%{http_code}\n" "${ARC_BASE}/app3/"
```

Si `/` responde pero una subruta no, revisa el LB Arcadia o el contenedor de ese backend concreto.

---

## 4. Arcadia

Arcadia es util para validar WAF web, API Discovery, API Protection y Bot Defense sobre un LB dedicado.

### 4.1. Login funcional

```bash
curl -s -X POST "${ARC_BASE}/trading/auth.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=matt&password=ilovef5" \
  -c "${ARC_COOKIE}" \
  -D - | grep -i "location:"
```

### 4.2. API Discovery

```bash
curl -s "${ARC_BASE}/trading/index.php" \
  -b "${ARC_COOKIE}" | grep -i "Arcadia - Account Information"

curl -s "${ARC_BASE}/api/side_bar.php" \
  -b "${ARC_COOKIE}" > /dev/null

curl -s "${ARC_BASE}/api/side_bar_accounts.php" \
  -b "${ARC_COOKIE}" | grep -E "Select Acount|Acc-"

curl -s "${ARC_BASE}/trading/transactions.php" \
  -b "${ARC_COOKIE}" > /dev/null
```

Notas:

- `side_bar_accounts.php` devuelve HTML con opciones `<option>`, no JSON
- `trading/rest/portfolio.php` puede responder `504` en este despliegue y no es una buena validacion inicial de sesion

### 4.3. Bot Defense en login

```bash
for cred in "matt:bad1" "matt:bad2" "matt:bad3" "admin:admin"; do
  user=$(echo "$cred" | cut -d: -f1)
  pass=$(echo "$cred" | cut -d: -f2)
  curl -s -o /dev/null -w "%{http_code}\n" -X POST \
    "${ARC_BASE}/trading/auth.php" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${user}&password=${pass}"
done
```

### 4.4. Payload web clasico

```bash
curl -i "${ARC_BASE}/?x=<script>alert(1)</script>"
```

Que revisar en XC:

- eventos del LB Arcadia
- rutas descubiertas
- eventos Bot Defense sobre `POST /trading/auth.php`

---

## 5. DVWA

DVWA sirve para validar ataques web clasicos sobre su LB dedicado.

### 5.1. SQLi

```bash
curl -i -G "${DVWA_BASE}/vulnerabilities/sqli/" \
  --data-urlencode "id=1' or '1'='1" \
  --data-urlencode "Submit=Submit" \
  -H "Cookie: PHPSESSID=<tu_sesion>; security=low"
```

### 5.2. XSS reflejado

```bash
curl -i -G "${DVWA_BASE}/vulnerabilities/xss_r/" \
  --data-urlencode "name=<script>alert(1)</script>" \
  --data-urlencode "submit=Submit" \
  -H "Cookie: PHPSESSID=<tu_sesion>; security=low"
```

### 5.3. Fuerza bruta

```bash
for p in admin password 123456 letmein dvwa; do
  curl -s -o /dev/null -w "%{http_code}\n" -G \
    "${DVWA_BASE}/vulnerabilities/brute/" \
    --data-urlencode "username=admin" \
    --data-urlencode "password=${p}" \
    --data-urlencode "Login=Login" \
    -H "Cookie: PHPSESSID=<tu_sesion>; security=low"
done
```

Que revisar en XC:

- eventos WAF del LB DVWA
- volumen por IP si se aplica rate limiting

---

## 6. Boutique

Boutique es util para disponibilidad del frontend, pruebas ligeras de WAF y abuso HTTP.

### 6.1. Acceso basico

```bash
curl -I "${BOUTIQUE_BASE}/"
curl -I "${BOUTIQUE_BASE}/cart"
```

### 6.2. XSS en query string

```bash
curl -i "${BOUTIQUE_BASE}/?x=<script>alert(1)</script>"
```

### 6.3. Flood ligero

```bash
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}\n" "${BOUTIQUE_BASE}/"
done
```

Que revisar en XC:

- eventos WAF del LB Boutique
- sintomas de rate limiting si existen controles L7

---

## 7. crAPI

En esta variante `4lbs`, crAPI queda con LB dedicado, **API Discovery** y **API Protection**. Arcadia mantiene **API Discovery** y Bot Defense, pero la validacion OpenAPI se concentra en crAPI para reducir consumo de cuota.

### 7.1. Acceso basico

```bash
curl -i "${CRAPI_BASE}/"
curl -i "${CRAPI_BASE}/identity/api/auth/login"
```

### 7.2. Token invalido

```bash
curl -i -X GET "${CRAPI_BASE}/workshop/api/me" \
  -H "Authorization: Bearer token_invalido"
```

### 7.3. Content-Type anomalo

```bash
curl -i -X POST "${CRAPI_BASE}/identity/api/auth/login" \
  -H "Content-Type: text/plain" \
  -d 'username=test&password=test'
```

### 7.4. JSON malformado

```bash
curl -i -X POST "${CRAPI_BASE}/identity/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":'
```

Que revisar en XC:

- endpoints descubiertos en el LB crAPI
- violaciones de schema si API Protection esta activa
- diferencia entre trafico normal y anomalo

---

## 8. Mailhog

Mailhog comparte el LB de crAPI, por eso conviene validar especificamente ese enrutamiento.

### 8.1. Acceso basico

```bash
curl -i "${MAILHOG_BASE}/"
```

### 8.2. Validacion conjunta con crAPI

```bash
curl -s -o /dev/null -w "crapi=%{http_code}\n" "${CRAPI_BASE}/"
curl -s -o /dev/null -w "mailhog=%{http_code}\n" "${MAILHOG_BASE}/"
```

Si crAPI responde y Mailhog no:

- revisar que `MAILHOG_DOMAIN` este asociado al LB de crAPI
- revisar que la ruta `Host: MAILHOG_DOMAIN -> mailhog` exista
- revisar el origin pool del puerto `18087`

---

## 9. Que revisar en F5 XC

Este caso tiene valor porque puedes revisar cada LB de forma independiente:

- LB Arcadia
- LB DVWA
- LB Boutique
- LB crAPI

Checklist recomendado:

- dominios asociados a cada LB
- estado de salud de cada origin pool
- eventos WAF por dominio
- endpoints descubiertos en Arcadia y crAPI
- presencia de Mailhog dentro del LB crAPI
- diferencias de eventos entre LBs dedicados

---

## 10. Diagnostico rapido

### Caso: solo falla una aplicacion

Revisar:

- que el dominio este en el LB correcto
- que el LB correspondiente exista y este activo
- que el origin pool del backend afectado este healthy

### Caso: Arcadia raiz responde pero `/files` o `/api` no

Revisar:

- rutas del LB Arcadia
- pools `arcadia_files`, `arcadia_api`, `arcadia_app3`
- contenedor afectado en la VM

### Caso: crAPI responde pero Mailhog no

Revisar:

- asociacion de `MAILHOG_DOMAIN` al LB crAPI
- ruta por Host hacia el pool `mailhog`
- disponibilidad del puerto `18087`

### Caso: varias aplicaciones fallan a la vez

Revisar:

- estado general de la VM compartida
- SG de AWS para puertos `18080-18087`
- EIP asociada a la instancia
- health checks y origin pools en XC