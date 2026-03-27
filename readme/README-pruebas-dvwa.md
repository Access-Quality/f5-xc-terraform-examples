# Pruebas de Seguridad para DVWA y Mitigación con F5 Distributed Cloud Services

Esta guía describe **cómo realizar pruebas de seguridad controladas sobre DVWA** y **cómo mitigarlas con F5 Distributed Cloud Services (F5 DCS)** cuando DVWA está publicado detrás del caso compartido de `todas`.

La guía está pensada para un **entorno de laboratorio**. No debe usarse contra sistemas de terceros ni fuera de un entorno autorizado.

---

## 1. Objetivo

DVWA es una aplicación deliberadamente vulnerable. Su valor en este laboratorio es que permite validar, con una sola app, múltiples controles de F5 DCS:

- WAF para ataques web clásicos
- rate limiting para abuso repetitivo
- Bot Defense para tráfico automatizado
- protección de rutas sensibles por hostname y path
- observabilidad de eventos y tuning de políticas antes de pasar a bloqueo

No todas las debilidades de DVWA se corrigen solo con F5 DCS. Algunas se **mitigan directamente** en el edge; otras requieren **cambios en la aplicación** y F5 DCS solo ayuda a reducir exposición, detectar patrones o añadir controles compensatorios.

---

## 2. Suposiciones de esta guía

Esta guía asume:

- DVWA está accesible por `http://DVWA_DOMAIN/`
- DVWA forma parte del workflow `sec-re-aws-todas-apply.yml`
- el tráfico pasa por el HTTP Load Balancer de F5 XC en el Regional Edge
- el origen real está protegido detrás del LB compartido
- se pueden observar eventos en F5 XC mientras se ejecutan las pruebas

URL base esperada:

```text
http://DVWA_DOMAIN/
```

Rutas relevantes de DVWA:

- `/login.php`
- `/setup.php`
- `/security.php`
- `/vulnerabilities/brute/`
- `/vulnerabilities/sqli/`
- `/vulnerabilities/sqli_blind/`
- `/vulnerabilities/xss_r/`
- `/vulnerabilities/xss_s/`
- `/vulnerabilities/xss_d/`
- `/vulnerabilities/exec/`
- `/vulnerabilities/fi/`
- `/vulnerabilities/upload/`
- `/vulnerabilities/csrf/`
- `/vulnerabilities/captcha/`
- `/vulnerabilities/open_redirect/`
- `/vulnerabilities/weak_id/`

---

## 3. Preparación del entorno de prueba

### 3.1. Inicializar DVWA

1. Abrir `http://DVWA_DOMAIN/setup.php`
2. Crear o inicializar la base de datos de DVWA
3. Iniciar sesión en `http://DVWA_DOMAIN/login.php`
4. Ajustar el nivel en `DVWA Security` según la prueba

### 3.2. Nivel de dificultad recomendado

Para validar mitigación en el edge conviene empezar por:

- `Low` para confirmar el comportamiento vulnerable
- `Medium` para validar bypasses simples
- `High` para comprobar que F5 DCS sigue aportando valor sobre lógica más restrictiva

### 3.3. Recomendación de política en F5 DCS

Antes de lanzar payloads, usa este enfoque:

1. WAF en `report`
2. ejecutar pruebas
3. revisar logs, signatures, paths y parámetros afectados
4. ajustar exclusiones o reglas personalizadas
5. pasar a `blocking` solo cuando el tuning sea aceptable

---

## 4. Qué mitiga F5 DCS y qué no

| Categoría | Mitigación con F5 DCS | Nivel de cobertura |
| --- | --- | --- |
| SQL Injection | WAF signatures, parámetros y rutas sensibles | Alta |
| XSS Reflected / Stored / DOM | WAF signatures y controles de request | Alta para reflected/stored, parcial para DOM |
| Command Injection | WAF signatures | Alta |
| File Inclusion / Path Traversal | WAF signatures, normalización de rutas | Alta |
| File Upload malicioso | WAF + restricciones por método/tamaño/header + validación de contenido | Media/Alta |
| Brute force | Rate limiting, Bot Defense, reputación, enforcement por ruta | Alta |
| CSRF | Principalmente corrección en la app; F5 ayuda con controles compensatorios | Baja/Media |
| Weak Session IDs | Requiere corrección en la app; F5 ayuda indirectamente | Baja |
| Open Redirect | Reglas específicas y validación por parámetros | Media |
| Insecure CAPTCHA | Bot Defense y rate limiting ayudan, pero no sustituyen lógica robusta | Media |
| DDoS L7 / flooding | Limitación de tasa y controles L7 | Alta |

Regla práctica:

- si el ataque depende de **payload malicioso en request**, F5 DCS suele mitigarlo bien
- si el problema es **lógica insegura de la aplicación**, F5 DCS ayuda pero no reemplaza un fix del origen

---

## 5. Flujo recomendado de validación

Para cada módulo de DVWA usa la misma secuencia:

1. confirmar la vulnerabilidad sin mitigación estricta
2. observar el evento en F5 DCS
3. activar o endurecer la mitigación adecuada
4. repetir la misma prueba
5. comprobar si el tráfico queda bloqueado, marcado o limitado
6. documentar el path, método, parámetro y señal observada

---

## 6. Módulos y pruebas de seguridad

## 6.1. Brute Force

Ruta principal:

```text
/vulnerabilities/brute/
```

### Qué valida

- intentos repetitivos de autenticación
- abuso por volumen sobre credenciales
- protección del path más didáctico para login guessing en DVWA

### Cómo probarlo

1. entrar al módulo `Brute Force`
2. dejar DVWA en `Low`
3. lanzar múltiples intentos cambiando `password`

Ejemplo de prueba controlada:

```bash
for p in admin password 123456 letmein dvwa qwerty; do
  curl -s -G "http://DVWA_DOMAIN/vulnerabilities/brute/" \
    --data-urlencode "username=admin" \
    --data-urlencode "password=${p}" \
    --data-urlencode "Login=Login" \
    -H "Cookie: PHPSESSID=<SESSION>; security=low" \
    | head -n 5
done
```

### Qué deberías observar

- respuestas repetidas desde la misma IP o sesión
- patrón claro de automatización
- posible éxito si usas credenciales válidas del laboratorio

### Mitigación recomendada con F5 DCS

La mitigación principal aquí es **rate limiting**, no JS challenge.

Controles recomendados:

- rate limiting sobre `GET /vulnerabilities/brute/`
- rate limiting adicional sobre `/login.php`
- Bot Defense si quieres etiquetar o frenar automatización genérica
- alertas por tasa anormal por IP, ASN o fingerprint

### Recomendación operativa

- usar `report` al inicio para medir el umbral real
- después activar limitación por ventana de tiempo
- si la demo lo requiere, bloquear solo cuando se supere un número muy claro de intentos por minuto

### Mitigación en la aplicación

- MFA
- bloqueo progresivo
- captcha real
- invalidación de sesión
- logging de autenticación más robusto

---

## 6.2. SQL Injection

Ruta principal:

```text
/vulnerabilities/sqli/
```

### Qué valida

- inyección de payloads en parámetros de consulta
- detección de firmas SQLi por el WAF

### Cómo probarlo

Para payloads en query string, evita escribir la URL completa con espacios o comillas sin codificar. En DVWA es mas robusto usar `curl -G` con `--data-urlencode`.

Ejemplo controlado típico en DVWA:

```bash
curl -i -G "http://DVWA_DOMAIN/vulnerabilities/sqli/" \
  --data-urlencode "id=1' or '1'='1" \
  --data-urlencode "Submit=Submit" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Qué deberías observar

- respuesta anómala con más de un registro
- errores de SQL o resultados no esperados
- evento de WAF marcando SQL Injection si está en report o bloqueo

### Mitigación recomendada con F5 DCS

- WAF con firmas SQLi habilitadas
- revisión de parámetros de entrada del path
- pasar a `blocking` tras verificar que no rompe el uso legítimo

### Afinación sugerida

- revisar el parámetro `id`
- observar si hay false positives con valores especiales
- dejar una excepción solo si existe un caso legítimo, no de forma global

### Mitigación en la aplicación

- consultas parametrizadas
- ORM seguro
- validación estricta de tipos
- no exponer errores SQL al cliente

---

## 6.3. SQL Injection Blind

Ruta principal:

```text
/vulnerabilities/sqli_blind/
```

### Qué valida

- inyección basada en diferencias de tiempo o respuesta indirecta
- capacidad del WAF para detectar patrones SQLi menos evidentes

### Cómo probarlo

Ejemplo de prueba controlada:

```bash
curl -i -G "http://DVWA_DOMAIN/vulnerabilities/sqli_blind/" \
  --data-urlencode "id=1' AND sleep(3)-- -" \
  --data-urlencode "Submit=Submit" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Qué deberías observar

- incremento de latencia o comportamiento binario verdadero/falso
- alertas de SQLi en F5 DCS si la firma detecta el patrón

### Mitigación recomendada con F5 DCS

- mismo enfoque de SQLi clásico
- alertas por patrones repetitivos de sondeo
- rate limiting si ves enumeración iterativa

### Mitigación en la aplicación

- prepared statements
- reducción del tiempo de respuesta diferencial
- respuesta uniforme ante errores y consultas inválidas

---

## 6.4. Reflected XSS

Ruta principal:

```text
/vulnerabilities/xss_r/
```

### Qué valida

- payloads reflejados desde query string o form input
- capacidad del WAF para detectar `<script>`, handlers inline y vectores equivalentes

### Cómo probarlo

Ejemplo controlado:

```bash
curl -i -G "http://DVWA_DOMAIN/vulnerabilities/xss_r/" \
  --data-urlencode "name=<script>alert(1)</script>" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Mitigación recomendada con F5 DCS

- WAF con firmas XSS habilitadas
- bloqueo de payloads con tags, eventos inline y patrones conocidos

### Mitigación en la aplicación

- output encoding contextual
- sanitización según contexto HTML/JS/URL
- CSP robusta

---

## 6.5. Stored XSS

Ruta principal:

```text
/vulnerabilities/xss_s/
```

### Qué valida

- payload persistente guardado en servidor y renderizado luego a otro usuario

### Cómo probarlo

1. enviar un comentario o campo persistente con payload simple
2. recargar la página y confirmar persistencia

Prueba controlada típica:

```text
<script>alert(1)</script>
```

### Mitigación recomendada con F5 DCS

- WAF en el request de carga del contenido
- reglas de firma XSS en los parámetros del formulario

### Limitación importante

F5 DCS puede bloquear el **request de entrada**, pero si el payload ya está almacenado en DVWA y llega desde backend, el problema real sigue siendo del origen.

### Mitigación en la aplicación

- sanitización al guardar
- output encoding al renderizar
- CSP
- revisión de datos persistidos antes de reusar el entorno

---

## 6.6. DOM XSS

Ruta principal:

```text
/vulnerabilities/xss_d/
```

### Qué valida

- manipulación client-side del DOM a partir de fragmentos o parámetros

### Cómo probarlo

Usa payloads que modifiquen la lógica del navegador en la URL o fragmento. En este módulo la explotación depende más del JavaScript del cliente que del request puro al backend.

### Mitigación recomendada con F5 DCS

- cobertura parcial con WAF si el payload viaja en request observable
- protección complementaria con headers y CSP desde origen

### Mitigación en la aplicación

- eliminar sinks inseguros en JavaScript
- sanitizar entradas antes de escribir en DOM
- CSP estricta

---

## 6.7. Command Injection

Ruta principal:

```text
/vulnerabilities/exec/
```

### Qué valida

- concatenación insegura de input en comandos del sistema

### Cómo probarlo

Prueba controlada con separación de comandos:

```bash
curl -i "http://DVWA_DOMAIN/vulnerabilities/exec/?ip=127.0.0.1;id&Submit=Submit" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Qué deberías observar

- ejecución no prevista del comando adicional
- respuesta anómala o salida del sistema

### Mitigación recomendada con F5 DCS

- WAF con firmas de command injection
- reglas específicas para caracteres separadores y patrones del shell
- bloqueo estricto de este path en modo `blocking` una vez afinado

### Mitigación en la aplicación

- no construir comandos con input del usuario
- allowlist de valores válidos
- uso de APIs del sistema en lugar de shell

---

## 6.8. File Inclusion

Ruta principal:

```text
/vulnerabilities/fi/
```

### Qué valida

- LFI/RFI
- path traversal

### Cómo probarlo

Pruebas controladas típicas:

```bash
curl -i "http://DVWA_DOMAIN/vulnerabilities/fi/?page=../../../../etc/passwd" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Mitigación recomendada con F5 DCS

- firmas contra path traversal
- normalización de rutas
- bloqueo de patrones `../`, wrappers y rutas absolutas sospechosas

### Mitigación en la aplicación

- allowlist de archivos
- resolución segura de paths
- no incluir archivos basados en input libre

---

## 6.9. File Upload

Ruta principal:

```text
/vulnerabilities/upload/
```

### Qué valida

- subida de ficheros peligrosos o ejecutables
- validación de tamaño, nombre, tipo y contenido

### Cómo probarlo

1. preparar un archivo de prueba del laboratorio
2. intentar subir un tipo no permitido
3. probar extensiones dobles o content-type engañoso

Ejemplo de enfoque:

- archivo con extensión inesperada
- `multipart/form-data` alterado
- tamaño superior al esperado

### Mitigación recomendada con F5 DCS

- limitar métodos y paths de upload
- restringir tamaños de request
- revisar headers y content-type
- reglas WAF para payloads peligrosos y extensiones de alto riesgo

### Mitigación en la aplicación

- validación por contenido real y no solo por extensión
- rename del archivo en backend
- almacenamiento fuera del webroot
- antivirus/sandbox si aplica

---

## 6.10. CSRF

Ruta principal:

```text
/vulnerabilities/csrf/
```

### Qué valida

- acciones sensibles que pueden dispararse sin intención del usuario autenticado

### Cómo probarlo

1. identificar una acción sensible del módulo
2. replicarla desde un request forjado sin controles adicionales

### Mitigación con F5 DCS

Cobertura limitada. F5 DCS ayuda como control complementario, pero no es la solución principal.

Puede ayudar con:

- protección adicional de rutas sensibles
- políticas por método y path
- telemetría y control de automatización

### Mitigación principal en la aplicación

- tokens CSRF
- cookies `SameSite`
- reautenticación en acciones críticas
- validación estricta de origen y sesión

---

## 6.11. Insecure CAPTCHA

Ruta principal:

```text
/vulnerabilities/captcha/
```

### Qué valida

- debilidad de mecanismos anti-bot triviales

### Cómo probarlo

- automatizar requests repetidos contra el flujo del módulo
- comprobar si el CAPTCHA puede eludirse con secuencias simples o replay

### Mitigación recomendada con F5 DCS

- Bot Defense
- rate limiting
- mitigación por reputación o fingerprint

### Mitigación en la aplicación

- CAPTCHA real y resistente a replay
- tokens efímeros
- validación de flujo y sesión

---

## 6.12. Weak Session IDs

Ruta principal:

```text
/vulnerabilities/weak_id/
```

### Qué valida

- predictibilidad de identificadores de sesión
- mala aleatoriedad o secuencia fácil de inferir

### Cómo probarlo

- observar varios IDs generados
- analizar si son secuenciales o predecibles

### Mitigación con F5 DCS

F5 DCS no corrige la generación insegura del ID. Solo puede ayudar de forma indirecta mediante:

- observación de abuso por sesión/IP
- controles de acceso y automatización
- endurecimiento de cookies si el diseño lo permite

### Mitigación real

- regeneración de sesión
- CSPRNG
- flags seguras de cookie
- tiempo de vida controlado

---

## 6.13. Open Redirect

Ruta principal:

```text
/vulnerabilities/open_redirect/
```

### Qué valida

- redirección del usuario a dominios controlados por atacante

### Cómo probarlo

- localizar el parámetro de destino
- probar una URL externa controlada para el laboratorio

### Mitigación recomendada con F5 DCS

- reglas por parámetro para bloquear `http://`, `https://` externos si no están permitidos
- validación por allowlist de dominios de retorno

### Mitigación en la aplicación

- allowlist de destinos
- tokens de retorno firmados
- no redirigir usando input arbitrario

---

## 6.14. JavaScript y módulos cliente

DVWA incluye módulos o retos donde la validación ocurre en navegador o lógica cliente.

### Mitigación con F5 DCS

- limitada si el problema está enteramente en la lógica del browser
- útil como capa complementaria de observación y control L7

### Mitigación principal

- eliminar validaciones exclusivas en cliente
- mover controles al backend
- CSP y sanitización contextual

---

## 7. Mapeo rápido módulo -> mitigación F5 DCS

| Módulo DVWA | Ruta | Mitigación principal en F5 DCS |
| --- | --- | --- |
| Brute Force | `/vulnerabilities/brute/` | Rate limiting + Bot Defense |
| SQLi | `/vulnerabilities/sqli/` | WAF SQLi |
| SQLi Blind | `/vulnerabilities/sqli_blind/` | WAF SQLi + rate limiting |
| Reflected XSS | `/vulnerabilities/xss_r/` | WAF XSS |
| Stored XSS | `/vulnerabilities/xss_s/` | WAF en request de entrada |
| DOM XSS | `/vulnerabilities/xss_d/` | Cobertura parcial + CSP/app fix |
| Command Injection | `/vulnerabilities/exec/` | WAF command injection |
| File Inclusion | `/vulnerabilities/fi/` | WAF LFI/RFI/path traversal |
| File Upload | `/vulnerabilities/upload/` | WAF + restricciones de upload |
| CSRF | `/vulnerabilities/csrf/` | Control compensatorio, no solución principal |
| Insecure CAPTCHA | `/vulnerabilities/captcha/` | Bot Defense + rate limiting |
| Weak Session IDs | `/vulnerabilities/weak_id/` | Observación, no corrección directa |
| Open Redirect | `/vulnerabilities/open_redirect/` | Reglas por parámetro + allowlist |

---

## 8. Reglas prácticas para F5 DCS en DVWA

Para este laboratorio, la estrategia más útil suele ser:

1. publicar DVWA por su FQDN dedicado
2. activar WAF global en report
3. ejecutar una batería mínima por módulo
4. revisar eventos por path y parámetro
5. activar bloqueo en módulos claros:
   - SQLi
   - XSS reflected/stored
   - command injection
   - file inclusion
6. añadir rate limiting para:
   - `/login.php`
   - `/vulnerabilities/brute/`
7. evaluar Bot Defense en:
   - login principal
   - paths con repetición clara de requests

---

## 9. Qué revisar en F5 XC durante las pruebas

Durante las pruebas, revisa al menos:

- eventos de WAF por path
- firma disparada
- parámetro asociado
- IP origen
- tasa de requests
- diferencia entre tráfico permitido, reportado y bloqueado

Si el laboratorio está en modo `report`, documenta primero:

- qué payload disparó la firma
- si el evento fue correcto o falso positivo
- si conviene pasar a `blocking`

---

## 10. Orden recomendado de ejecución

Para una demo o validación ordenada, usa esta secuencia:

1. Brute Force
2. SQLi
3. SQLi Blind
4. Reflected XSS
5. Stored XSS
6. Command Injection
7. File Inclusion
8. File Upload
9. Open Redirect
10. CAPTCHA / Weak Session IDs / CSRF como ejemplos de límites del edge

Ese orden permite mostrar primero las mitigaciones que F5 DCS resuelve mejor y luego las que requieren medidas complementarias de aplicación.

---

## 11. Conclusión operativa

DVWA es especialmente útil para demostrar tres mensajes:

- F5 DCS mitiga muy bien ataques **de request malicioso**
- F5 DCS ayuda mucho contra **abuso automatizado** con rate limiting y Bot Defense
- F5 DCS no reemplaza un **fix de aplicación** cuando la vulnerabilidad es lógica, de sesión o de diseño

Si el objetivo es un laboratorio claro y realista, la combinación recomendada para DVWA es:

- WAF en `report` al inicio, luego `blocking`
- rate limiting para brute force
- Bot Defense como capa adicional, no como único control para `GET /vulnerabilities/brute/`
- revisión de eventos por módulo antes de endurecer