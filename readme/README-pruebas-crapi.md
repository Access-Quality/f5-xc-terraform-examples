# Pruebas de Seguridad para crAPI y Mitigación con F5 Distributed Cloud Services

Esta guía describe cómo realizar pruebas de seguridad controladas sobre **crAPI** y cómo mitigarlas con **F5 Distributed Cloud Services (F5 DCS)** cuando crAPI está publicado en el caso compartido de `todas`.

Está pensada para laboratorio, validación funcional y demostraciones autorizadas. No debe usarse contra sistemas fuera de tu entorno controlado.

---

## 1. Objetivo

crAPI es una aplicación diseñada para demostrar fallos comunes de seguridad en APIs y lógica de negocio. En este laboratorio sirve para validar varias capacidades de F5 DCS:

- **WAF** para payloads maliciosos y abuso de request
- **API Discovery** para inventario de endpoints observados
- **API Protection** para validación OpenAPI en modo report
- controles compensatorios frente a abuso de autenticación y automatización
- observabilidad de tráfico API por path, método, cabeceras y cuerpos

crAPI también es útil para dejar claro qué puede resolver el edge y qué requiere un fix en la aplicación:

- F5 DCS mitiga muy bien tráfico malicioso y patrones de abuso visibles en la request
- F5 DCS no corrige por sí solo problemas de **autorización rota**, **lógica de negocio insegura** o **BOLA/IDOR** cuando la request es sintácticamente válida

---

## 2. Suposiciones de esta guía

Se asume que:

- crAPI está accesible por `http://CRAPI_DOMAIN/`
- Mailhog está accesible por `http://MAILHOG_DOMAIN/`
- el tráfico entra por el HTTP Load Balancer de F5 XC en el Regional Edge
- el workflow `sec-re-aws-todas-apply.yml` se ha desplegado correctamente
- `XC_API_DISCOVERY=true` y `XC_API_PROTECTION=true` si quieres validar capacidades API completas
- la spec OpenAPI de crAPI fue subida con `XC_UPLOAD_CRAPI_API_SPEC=true`

URL base esperada:

```text
http://CRAPI_DOMAIN/
```

URL de apoyo para correo de laboratorio:

```text
http://MAILHOG_DOMAIN/
```

---

## 3. Preparación del entorno

### 3.1. Verificar acceso básico

Comprueba que la aplicación responde:

```bash
curl -i http://CRAPI_DOMAIN/
```

Comprueba que Mailhog responde:

```bash
curl -i http://MAILHOG_DOMAIN/
```

### 3.2. Revisar endpoints base

En esta implementación suelen ser relevantes:

- `/identity/api/auth/signup`
- `/identity/api/auth/login`
- `/identity/api/auth/forgot-password`
- `/identity/api/auth/v2/check-otp`
- `/identity/api/auth/v2/reset-password`
- `/workshop/api/`
- `/community/api/`

No dependas de una lista fija. Si API Discovery está activo, úsalo para descubrir el inventario real observado en tu despliegue.

### 3.3. Recomendación de política inicial

Antes de endurecer:

1. WAF en `report`
2. API Protection en `report`
3. ejecutar pruebas controladas
4. observar qué eventos son útiles y cuáles podrían ser falso positivo
5. decidir si alguna mitigación conviene pasar a bloqueo o si debe quedarse en modo observación

---

## 4. Qué puede mitigar F5 DCS en crAPI

| Categoría | Mitigación con F5 DCS | Cobertura |
| --- | --- | --- |
| Payloads maliciosos en query/body/headers | WAF | Alta |
| Desviaciones respecto a la spec OpenAPI | API Protection | Alta |
| Inventario de endpoints | API Discovery | Alta |
| Abuso de login / password reset / OTP | Rate limiting + controles compensatorios | Alta |
| Enumeración intensiva de recursos | Rate limiting y observabilidad | Media/Alta |
| BOLA / IDOR con requests válidas | Detección indirecta y controles de abuso | Baja/Media |
| Lógica de negocio rota | Principalmente corrección en app | Baja |
| SSRF si el payload es visible y anómalo | WAF + validación de schema | Media |
| Token inválido o malformado | WAF/API Protection/observabilidad | Media |

Regla práctica:

- si la request es maliciosa a nivel de contenido, F5 DCS suele ayudar mucho
- si la request es perfectamente válida pero el backend autoriza mal, el problema es del origen

---

## 5. Flujo recomendado de validación

Para cada categoría de prueba:

1. confirmar comportamiento normal del endpoint
2. ejecutar la variante anómala o maliciosa
3. revisar eventos en F5 DCS
4. comprobar si hubo `report`, `flag`, limitación o bloqueo
5. documentar path, método, payload y resultado

---

## 6. Pruebas por categoría

## 6.1. API Discovery

### Qué valida

- que F5 DCS aprenda y catalogue endpoints reales de crAPI
- visibilidad de métodos, paths y tráfico activo

### Cómo probarlo

Genera tráfico legítimo y variado:

1. abre la UI de crAPI
2. regístrate
3. inicia sesión
4. navega por varios módulos
5. llama endpoints con `curl` o Postman

Ejemplo:

```bash
curl -i http://CRAPI_DOMAIN/identity/api/auth/login
curl -i http://CRAPI_DOMAIN/workshop/api/me
curl -i http://CRAPI_DOMAIN/community/api/v2/community/posts
```

### Qué observar en F5 DCS

- endpoints descubiertos
- paths nuevos no presentes en el inventario previo
- métodos usados por cada path
- frecuencia y volumen

### Mitigación / valor operativo

API Discovery no bloquea por sí solo. Su valor es:

- entender superficie expuesta real
- detectar shadow endpoints o paths no esperados
- decidir qué debe quedar cubierto por OpenAPI y validación estricta

---

## 6.2. API Protection con OpenAPI

### Qué valida

- requests que no cumplen la spec
- content-types inesperados
- parámetros, headers o cuerpos fuera de contrato

### Cómo probarlo

Prueba variantes anómalas sobre endpoints conocidos.

Ejemplos:

#### Content-Type inválido

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/login" \
  -H "Content-Type: text/plain" \
  -d 'username=test&password=test'
```

#### JSON malformado

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":'
```

#### Parámetros no esperados

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/login?debug=true&admin=true" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"secret"}'
```

### Qué observar

- violaciones de schema en modo report
- diferencias entre tráfico conforme y tráfico fuera de contrato
- endpoints que todavía no quedan bien representados por la spec

### Mitigación con F5 DCS

- mantener API Protection en report mientras afinas la spec y el tráfico real
- si la cobertura es buena, evaluar endurecimiento posterior

### Limitación importante

API Protection valida contrato, no autorización. Una request perfectamente válida según OpenAPI puede seguir siendo insegura si la lógica backend es incorrecta.

---

## 6.3. Login, autenticación y abuso de credenciales

Rutas típicas:

- `/identity/api/auth/signup`
- `/identity/api/auth/login`
- `/identity/api/auth/forgot-password`
- `/identity/api/auth/v2/check-otp`
- `/identity/api/auth/v2/reset-password`

### Qué valida

- abuso de login
- forcing de OTP o reset flow
- automatización de secuencias de autenticación

### Cómo probarlo

#### Login con token o credenciales inválidas

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"incorrecta"}'
```

#### Ataque repetitivo controlado

```bash
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST "http://CRAPI_DOMAIN/identity/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"user@example.com","password":"incorrecta"}'
done
```

### Mitigación con F5 DCS

- rate limiting por path y método
- umbrales específicos para login, OTP y reset password
- alertas por ráfagas desde una sola IP o fingerprint

### Mitigación en la aplicación

- MFA
- bloqueo progresivo
- límites por usuario y por cuenta
- OTP robusto y antifuerza bruta

---

## 6.4. Token inválido, expirado o malformado

### Qué valida

- comportamiento ante JWT inválidos o no autorizados
- observabilidad sobre cabeceras y autenticación fallida

### Cómo probarlo

Ejemplo simple:

```bash
curl -i "http://CRAPI_DOMAIN/workshop/api/me" \
  -H "Authorization: Bearer token_invalido"
```

### Qué observar

- respuesta del backend
- logs de autenticación fallida
- si API Protection reporta anomalías de cabecera o formato cuando corresponde

### Mitigación con F5 DCS

- validación adicional de headers esperados
- detección de patrones repetidos de acceso con tokens inválidos
- rate limiting por path autenticado

### Mitigación real

- validación fuerte del token en backend
- expiración, rotación y manejo seguro de sesión

---

## 6.5. BOLA / IDOR

### Qué valida

- acceso a recursos de otro usuario modificando un identificador
- una de las clases más relevantes en APIs modernas

### Cómo probarlo

1. autenticar dos usuarios distintos
2. capturar requests válidas del usuario A
3. cambiar identificadores o recursos hacia los del usuario B
4. comprobar si el backend autoriza indebidamente

Este tipo de prueba suele requerir navegación real en la UI, DevTools o un proxy como Burp.

### Qué observar

- si la request sigue siendo completamente válida a nivel de sintaxis
- si el backend devuelve datos o acciones de otro usuario

### Mitigación con F5 DCS

Cobertura limitada.

F5 DCS puede ayudar con:

- visibilidad de patrones de enumeración
- rate limiting de secuencias intensivas
- detección de abuso en paths sensibles

Pero no puede inferir por sí solo la autorización correcta del recurso si la request parece legítima.

### Mitigación en la aplicación

- autorización a nivel de objeto
- validación de ownership en backend
- no confiar solo en IDs enviados por el cliente

---

## 6.6. SSRF y payloads de URL externas

### Qué valida

- inserción de URLs externas o internas si algún endpoint de crAPI acepta referencias remotas

### Cómo probarlo

Depende del endpoint concreto. Si existe un parámetro que recibe URL o recurso externo, prueba variaciones controladas:

- URL externa controlada
- URL interna tipo `http://127.0.0.1`
- metadatos cloud si aplica en laboratorio aislado

### Mitigación con F5 DCS

- WAF para patrones SSRF conocidos
- API Protection para restricciones de schema y formato
- allowlists si la lógica de negocio lo soporta

### Mitigación en la aplicación

- bloqueo de destinos internos
- resolución segura de hostnames
- allowlist de dominios salientes

---

## 6.7. Input tampering y parámetros inesperados

### Qué valida

- parámetros extra, tipos incorrectos, cuerpos anómalos
- diferencias entre requests soportadas y tráfico fuera de contrato

### Cómo probarlo

Ejemplos:

#### Campos extra

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","name":"demo","password":"secret","role":"admin","debug":true}'
```

#### Tipo de dato inesperado

```bash
curl -i -X POST "http://CRAPI_DOMAIN/identity/api/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":["demo@example.com"],"name":123,"password":false}'
```

### Mitigación con F5 DCS

- API Protection para schema mismatch
- WAF si el payload contiene patrones maliciosos clásicos

### Mitigación real

- validación backend robusta
- tipado estricto
- rechazo explícito de campos no soportados

---

## 6.8. Enumeración y scraping de recursos API

### Qué valida

- abuso a alta tasa de endpoints de lectura
- secuencias repetitivas de IDs o recursos

### Cómo probarlo

Si identificas un endpoint con IDs incrementales, prueba enumeración controlada:

```bash
for id in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code} ${id}\n" \
    "http://CRAPI_DOMAIN/workshop/api/some-resource/${id}" \
    -H "Authorization: Bearer <TOKEN_VALIDO>"
done
```

### Mitigación con F5 DCS

- rate limiting por path
- alertas por patrones de enumeración
- correlación por IP y volumen

### Limitación

Si el backend responde legítimamente con datos de otros usuarios, el problema de fondo sigue siendo autorización rota.

---

## 6.9. Restablecimiento de contraseña y uso de Mailhog

### Qué valida

- flujo de correo de recuperación
- dependencia funcional entre crAPI y Mailhog
- disponibilidad de datos auxiliares dentro del correo para continuar pruebas sobre crAPI

### Cómo probarlo

1. disparar el flujo de `forgot password`
2. abrir `http://MAILHOG_DOMAIN/`
3. localizar el correo de laboratorio
4. inspeccionar el contenido del mensaje y el enlace recibido

### Qué observar

- que crAPI genera el correo correctamente
- que Mailhog sigue siendo accesible pública y funcionalmente
- que no se exponen secretos innecesarios en el contenido del email

### Nota importante

Mailhog **no es el objetivo de la prueba de seguridad**. En este laboratorio se usa como apoyo operativo para:

- leer correos generados por crAPI
- obtener enlaces, tokens o datos auxiliares necesarios para continuar el flujo
- facilitar la obtencion de informacion relacionada con vehiculos o cuentas cuando el propio flujo de crAPI la expone por correo

### Mitigación con F5 DCS

- rate limiting del flujo de recovery
- observabilidad de abuso por correo/usuario/IP

### Mitigación en la aplicación

- links temporales firmados
- OTP robusto
- límites por usuario

---

## 7. Mapeo rápido categoría -> control de F5 DCS

| Categoría | Mitigación principal |
| --- | --- |
| Login abuse | Rate limiting |
| OTP abuse | Rate limiting |
| Password reset abuse | Rate limiting |
| Payload malicioso | WAF |
| Desviación OpenAPI | API Protection |
| Shadow endpoints | API Discovery |
| Enumeración intensiva | Rate limiting + observabilidad |
| BOLA / IDOR | Detección indirecta, no corrección directa |
| SSRF | WAF + validación de schema |

---

## 8. Qué revisar en F5 XC durante las pruebas

Revisa al menos:

- eventos WAF por path y método
- inventario de endpoints descubiertos
- violaciones de API Protection
- cabeceras y cuerpos anómalos
- IP origen y volumen
- diferencias entre tráfico permitido, reportado y limitado

Si estás en modo `report`, documenta:

- qué payload disparó el evento
- en qué endpoint ocurrió
- si la spec representa correctamente el tráfico esperado
- si conviene endurecer o solo observar

---

## 9. Orden recomendado de ejecución

Para una demo o validación ordenada:

1. acceso básico a la UI
2. login y signup legítimos
3. API Discovery con navegación real
4. API Protection con requests fuera de contrato
5. token inválido en endpoints autenticados
6. abuso de login / OTP / reset password
7. BOLA / IDOR
8. enumeración de recursos
9. flujo de recuperación y revisión en Mailhog

---

## 10. Conclusión operativa

crAPI es ideal para demostrar cuatro ideas:

- F5 DCS mejora mucho la seguridad de APIs visibles en el edge
- API Discovery y API Protection añaden valor real cuando existe una spec razonable
- los controles de tasa ayudan contra abuso operativo del flujo de autenticación
- los problemas de autorización a nivel de objeto siguen necesitando corrección en la aplicación

Si quieres una configuración útil para laboratorio controlado:

- WAF en `report` al inicio
- API Discovery activado
- API Protection activado en `report`
- rate limiting en login, forgot password, OTP y reset password
- revisión de Mailhog para validar los flujos de correo