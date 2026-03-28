# Pruebas rapidas para el caso AWS compartido con 4 LBs XC

Esta guia resume pruebas funcionales y de validacion publica para el escenario documentado en `readme/README-sec-re-aws-todas-4lbs-apply.md`.

Aplica al caso donde:

- la VM compartida corre en AWS sin nginx
- F5 XC publica 4 HTTP Load Balancers
- Mailhog comparte el LB de crAPI

## 1. Objetivo

Validar rapidamente que:

- cada dominio publico responde por el LB esperado
- Arcadia enruta correctamente `/`, `/files`, `/api` y `/app3`
- DVWA, Boutique y crAPI responden por sus LBs dedicados
- Mailhog responde por el mismo LB que crAPI

## 2. Dominios esperados

| Aplicacion | Dominio | LB esperado |
| --- | --- | --- |
| Arcadia | `ARCADIA_DOMAIN` | Arcadia |
| DVWA | `DVWA_DOMAIN` | DVWA |
| Boutique | `BOUTIQUE_DOMAIN` | Boutique |
| crAPI | `CRAPI_DOMAIN` | crAPI |
| Mailhog | `MAILHOG_DOMAIN` | crAPI |

Variables recomendadas:

```bash
export ARCADIA_DOMAIN="arcadia.digitalvs.com"
export DVWA_DOMAIN="dvwa.digitalvs.com"
export BOUTIQUE_DOMAIN="boutique.digitalvs.com"
export CRAPI_DOMAIN="crapi.digitalvs.com"
export MAILHOG_DOMAIN="mailhog.digitalvs.com"
```

## 3. Pruebas de disponibilidad basica

### 3.1. Arcadia

```bash
curl -i "http://${ARCADIA_DOMAIN}/"
curl -i "http://${ARCADIA_DOMAIN}/files/"
curl -i "http://${ARCADIA_DOMAIN}/api/"
curl -i "http://${ARCADIA_DOMAIN}/app3/"
```

Esperado:

- `/` responde `200`
- `/files/`, `/api/` y `/app3/` responden `200`, `301` o `302`

### 3.2. DVWA

```bash
curl -i "http://${DVWA_DOMAIN}/"
curl -i "http://${DVWA_DOMAIN}/login.php"
```

Esperado:

- respuesta `200`, `301` o `302`

### 3.3. Boutique

```bash
curl -i "http://${BOUTIQUE_DOMAIN}/"
```

Esperado:

- respuesta `200`

### 3.4. crAPI

```bash
curl -i "http://${CRAPI_DOMAIN}/"
curl -i "http://${CRAPI_DOMAIN}/identity/api/auth/login"
```

Esperado:

- la raiz responde `200`
- el endpoint de login responde con codigo coherente para el metodo usado

### 3.5. Mailhog

```bash
curl -i "http://${MAILHOG_DOMAIN}/"
```

Esperado:

- respuesta `200`

## 4. Pruebas de enrutamiento por aplicacion

### 4.1. Arcadia mantiene su routing interno en su propio LB

```bash
curl -s -o /dev/null -w "%{http_code}\n" "http://${ARCADIA_DOMAIN}/"
curl -s -o /dev/null -w "%{http_code}\n" "http://${ARCADIA_DOMAIN}/files/"
curl -s -o /dev/null -w "%{http_code}\n" "http://${ARCADIA_DOMAIN}/api/"
curl -s -o /dev/null -w "%{http_code}\n" "http://${ARCADIA_DOMAIN}/app3/"
```

Si `ARCADIA_DOMAIN` responde en `/` pero una subruta falla, el problema suele estar en el routing del LB Arcadia o en el contenedor de ese backend concreto.

### 4.2. Mailhog comparte LB con crAPI

La validacion funcional minima es esta:

```bash
curl -s -o /dev/null -w "crapi=%{http_code}\n" "http://${CRAPI_DOMAIN}/"
curl -s -o /dev/null -w "mailhog=%{http_code}\n" "http://${MAILHOG_DOMAIN}/"
```

Si crAPI responde y Mailhog no:

- revisar que `MAILHOG_DOMAIN` este en el LB de crAPI
- revisar la ruta `Host: MAILHOG_DOMAIN -> mailhog`
- revisar que el puerto `18087` responda en la VM

## 5. Pruebas rapidas de seguridad

### 5.1. DVWA SQLi

```bash
curl -i -G "http://${DVWA_DOMAIN}/vulnerabilities/sqli/" \
  --data-urlencode "id=1' or '1'='1" \
  --data-urlencode "Submit=Submit" \
  -H "Cookie: PHPSESSID=<tu_sesion>; security=low"
```

Utilidad:

- comprobar eventos WAF sobre el LB de DVWA

### 5.2. crAPI token invalido

```bash
curl -i -X GET "http://${CRAPI_DOMAIN}/workshop/api/me" \
  -H "Authorization: Bearer token_invalido"
```

Utilidad:

- validar visibilidad de trafico API en el LB de crAPI
- revisar eventos WAF, API Discovery o API Protection del LB de crAPI

### 5.3. Arcadia login

```bash
curl -i -X POST "http://${ARCADIA_DOMAIN}/trading/auth.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=matt&password=ilovef5"
```

Utilidad:

- validar login de negocio
- revisar Bot Defense si esta habilitado

## 6. Que revisar en F5 XC

Para este caso interesa revisar cada LB por separado:

- LB Arcadia: rutas `/`, `/files`, `/api`, `/app3`
- LB DVWA: eventos WAF web clasicos
- LB Boutique: disponibilidad y trafico frontal
- LB crAPI: eventos API y ruta de Mailhog

Verificaciones utiles:

- estado de salud de cada origin pool
- dominios asociados a cada LB
- eventos WAF por dominio
- endpoints descubiertos en Arcadia y crAPI
- si Mailhog aparece bajo el LB de crAPI

## 7. Diagnostico rapido

### Caso: solo falla una aplicacion

Revisar:

- que el dominio apunte al LB correcto
- que el LB tenga el dominio asociado
- que el origin pool correspondiente este healthy

### Caso: solo falla Mailhog

Revisar:

- que `MAILHOG_DOMAIN` este en el LB de crAPI
- que exista la ruta hacia el pool `mailhog`
- que el puerto `18087` este activo en la VM

### Caso: Arcadia raiz responde pero una subruta no

Revisar:

- pool `arcadia_files`, `arcadia_api` o `arcadia_app3`
- contenedor afectado en la VM
- configuracion de la ruta en el LB Arcadia