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

### 5.1. Cómo pasar de la GUI a CLI y cómo mirar F5 XC

Para casi todos los módulos de DVWA conviene usar este patrón:

1. reproducir la acción en la GUI de DVWA para entender el flujo normal
2. abrir las herramientas del navegador en `Network`
3. localizar el request exacto que genera el módulo
4. usar `Copy as cURL` o replicar a mano el mismo método, path, parámetros y cookie de sesión
5. lanzar varias repeticiones por CLI para que el patrón quede más claro en F5 XC

En F5 XC, durante cada prueba, revisa al menos:

- el HTTP Load Balancer que publica DVWA
- los eventos de seguridad o analytics asociados al path probado
- el path, método, código de respuesta y acción aplicada
- la IP origen, la tasa de requests y el parámetro que disparó la detección
- si el tráfico quedó `reported`, `blocked`, `rate limited` o simplemente `allowed`

Regla práctica:

- si el ataque viaja en query string, body, headers o cookies, suele dejar evidencia clara en WAF o analytics L7
- si el problema vive sobre todo en el navegador, como DOM XSS, F5 XC solo verá la parte del flujo que realmente salga por la red

---

## 6. Módulos y pruebas de seguridad

## 6.1. Brute Force

Ruta principal:

```text
/vulnerabilities/brute/
```

### Qué hace el ataque

Este módulo simula un login vulnerable a adivinación repetitiva de credenciales. El objetivo del atacante no es romper la aplicación con un payload extraño, sino probar muchos usuarios o contraseñas hasta acertar.

### Cómo reproducirlo desde la GUI

1. entrar en `Brute Force`
2. dejar DVWA en `Low`
3. escribir `admin` como usuario
4. probar varias contraseñas seguidas desde el mismo navegador
5. observar si la aplicación responde siempre igual o si termina aceptando una credencial válida

### Cómo reproducirlo con comandos

Este módulo sí se presta bien a CLI porque el flujo vulnerable ocurre en `GET /vulnerabilities/brute/`.

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

### Cómo verlo en F5 XC

- buscar el path `/vulnerabilities/brute/`
- comprobar múltiples requests desde la misma IP, cookie o fingerprint en una ventana corta
- validar si aparece acción de `rate limited` o bloqueo al superar el umbral
- revisar si Bot Defense o analytics clasifican el patrón como automatización

### Mitigación recomendada con F5 DCS

La mitigación principal aquí es **rate limiting**, no JS challenge.

Controles recomendados:

- rate limiting sobre `GET /vulnerabilities/brute/`; cuando F5 alcance el umbral configurado, esa acción quedará bloqueada por el propio enforcement del rate limiting aunque el WAF o la política general no estén en `blocking`
- si también quieres proteger la autenticación inicial de DVWA, puedes añadir rate limiting sobre `/login.php`, pero las pruebas de este módulo y el abuso principal del laboratorio ocurren sobre `/vulnerabilities/brute/`
- Bot Defense si quieres etiquetar o frenar automatización genérica
- alertas por tasa anormal por IP, ASN o fingerprint

### Recomendación operativa

- usar `report` al inicio para medir el umbral real
- después activar limitación por ventana de tiempo
- definir un umbral muy claro de intentos por minuto, porque al superarlo F5 aplicará el bloqueo del rate limiting aunque la acción general siga sin pasar a `blocking`

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

### Qué hace el ataque

La inyección SQL busca alterar la consulta que la aplicación envía a la base de datos. En vez de tratar el valor de entrada como dato, la app lo concatena como parte de la lógica SQL.

### Cómo reproducirlo desde la GUI

1. abrir `SQL Injection`
2. dejar DVWA en `Low`
3. enviar un valor simple como `1` para ver la respuesta normal
4. repetir con un payload como `' or '1'='1`
5. comparar si la respuesta devuelve más registros o un comportamiento anómalo

### Cómo reproducirlo con comandos

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

### Cómo verlo en F5 XC

- filtrar por el path `/vulnerabilities/sqli/`
- revisar qué parámetro disparó la firma, normalmente `id`
- confirmar si el evento quedó en `report` o `blocked`
- anotar la firma o familia de firmas de SQLi y el valor recibido

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

### Qué hace el ataque

La SQLi blind no siempre devuelve errores o resultados visibles. En su lugar, el atacante infiere información porque la aplicación tarda más, responde distinto o cambia el contenido de manera sutil.

### Cómo reproducirlo desde la GUI

1. abrir `SQL Injection (Blind)`
2. enviar primero un valor inocuo para medir el comportamiento normal
3. repetir con un payload basado en tiempo o condición booleana
4. observar si la página tarda más o cambia la respuesta de verdadero a falso

### Cómo reproducirlo con comandos

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

### Cómo verlo en F5 XC

- buscar el path `/vulnerabilities/sqli_blind/`
- comparar tiempos de respuesta entre requests normales y maliciosos
- revisar si varias pruebas consecutivas muestran patrón de enumeración
- validar si el WAF detecta SQLi aun cuando la respuesta funcional no sea evidente

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

### Qué hace el ataque

El XSS reflejado devuelve al navegador el mismo payload enviado por el usuario. Si la aplicación lo inserta sin escapar, el navegador lo interpreta como HTML o JavaScript activo.

### Cómo reproducirlo desde la GUI

1. abrir `Reflected XSS`
2. enviar un nombre benigno para ver la respuesta normal
3. repetir con un payload simple como `<script>alert(1)</script>`
4. validar si el valor aparece reflejado en la respuesta o si el navegador ejecuta el script

### Cómo reproducirlo con comandos

Ejemplo controlado:

```bash
curl -i -G "http://DVWA_DOMAIN/vulnerabilities/xss_r/" \
  --data-urlencode "name=<script>alert(1)</script>" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Cómo verlo en F5 XC

- filtrar por `/vulnerabilities/xss_r/`
- revisar el parámetro `name` u otro campo de entrada
- confirmar si el WAF marcó la request por firmas XSS o patrones de script inline
- comparar una request normal y otra maliciosa para ver la diferencia en acción aplicada

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

### Qué hace el ataque

El XSS almacenado persiste en backend. El atacante envía un payload una sola vez y después cualquier usuario que visite la página afectada puede recibir ese contenido malicioso.

### Cómo reproducirlo desde la GUI

1. abrir `Stored XSS`
2. escribir un nombre o mensaje inocuo para ver el flujo normal
3. repetir con un payload simple en el campo persistente
4. guardar el contenido y recargar la página
5. verificar si el payload queda almacenado y se vuelve a renderizar

### Cómo reproducirlo con comandos

Ejemplo orientativo para el guestbook de DVWA:

```bash
curl -i -X POST "http://DVWA_DOMAIN/vulnerabilities/xss_s/" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low" \
  --data-urlencode "txtName=tester" \
  --data-urlencode "mtxMessage=<script>alert(1)</script>" \
  --data-urlencode "btnSign=Sign Guestbook"
```

Después de enviar el payload, vuelve a cargar la página desde navegador para confirmar si quedó persistido.

### Cómo verlo en F5 XC

- revisar el request de entrada que sube el contenido al path `/vulnerabilities/xss_s/`
- comprobar si el WAF detecta la carga maliciosa antes de que quede almacenada
- distinguir entre el request de inserción y el posterior renderizado desde backend
- recordar que F5 XC puede bloquear la entrada, pero no limpiar datos ya guardados en DVWA

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

### Qué hace el ataque

El DOM XSS ocurre cuando el propio JavaScript del navegador toma datos de la URL, del fragmento o de otro origen client-side y los inserta de forma insegura en el DOM. Aquí el problema principal puede existir aunque el backend no vea el payload completo.

### Cómo reproducirlo desde la GUI

1. abrir `DOM XSS`
2. localizar el parámetro o fragmento de URL que la página usa para mostrar contenido
3. insertar un payload simple en ese valor
4. recargar o volver a renderizar la vista
5. comprobar si el navegador modifica el DOM o ejecuta código

### Cómo reproducirlo con comandos

Este caso no suele reproducirse bien con `curl` porque el fragmento `#...` nunca se envía al servidor y parte de la lógica vive solo en el navegador. La forma más práctica es construir la URL maliciosa y abrirla en un navegador real.

Ejemplo orientativo:

```text
http://DVWA_DOMAIN/vulnerabilities/xss_d/#<script>alert(1)</script>
```

### Cómo verlo en F5 XC

- comprobar si el payload realmente viajó en query string o body; si solo va en el fragmento, F5 XC no lo verá
- revisar únicamente la parte de red observable por el LB
- usar DevTools del navegador junto con F5 XC para separar qué ocurrió en cliente y qué salió realmente por la red

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

### Qué hace el ataque

La inyección de comandos aparece cuando la aplicación concatena input del usuario dentro de un comando del sistema operativo. El atacante intenta romper el comando esperado y encadenar otro adicional.

### Cómo reproducirlo desde la GUI

1. abrir `Command Injection`
2. enviar una IP válida para observar la respuesta normal
3. repetir con un separador de shell y un comando adicional, por ejemplo `;id`
4. revisar si la salida incluye información que no corresponde a un simple ping

### Cómo reproducirlo con comandos

Prueba controlada con separación de comandos:

```bash
curl -i "http://DVWA_DOMAIN/vulnerabilities/exec/?ip=127.0.0.1;id&Submit=Submit" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Qué deberías observar

- ejecución no prevista del comando adicional
- respuesta anómala o salida del sistema

### Cómo verlo en F5 XC

- filtrar por `/vulnerabilities/exec/`
- revisar el parámetro `ip` u otro campo del formulario
- buscar firmas o señales ligadas a separadores de shell, metacaracteres o comandos del sistema
- confirmar si la acción pasó de `report` a `blocked` al endurecer el WAF

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

### Qué hace el ataque

La inclusión de archivos intenta forzar a la aplicación a cargar recursos no previstos. Puede buscar archivos locales sensibles, rutas relativas o referencias remotas, según cómo esté implementado el módulo.

### Cómo reproducirlo desde la GUI

1. abrir `File Inclusion`
2. identificar el parámetro que selecciona la página o recurso
3. probar primero un valor legítimo
4. repetir con una ruta relativa como `../../../../etc/passwd`
5. verificar si la respuesta devuelve contenido del sistema o un error anómalo

### Cómo reproducirlo con comandos

Pruebas controladas típicas:

```bash
curl -i "http://DVWA_DOMAIN/vulnerabilities/fi/?page=../../../../etc/passwd" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Cómo verlo en F5 XC

- buscar el path `/vulnerabilities/fi/`
- revisar el parámetro `page` o equivalente
- detectar patrones de path traversal como `../`, rutas absolutas o wrappers sospechosos
- observar si la normalización de rutas y las firmas del WAF disparan evento

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

### Qué hace el ataque

El riesgo del upload inseguro es que la aplicación acepte archivos peligrosos, demasiado grandes o disfrazados. El atacante intenta colar un archivo ejecutable o un contenido que luego pueda procesarse de forma insegura.

### Cómo reproducirlo desde la GUI

1. abrir `File Upload`
2. subir primero un archivo inocuo para entender el flujo permitido
3. repetir con un tipo no esperado por la aplicación
4. probar doble extensión, nombre sospechoso o `content-type` inconsistente
5. verificar si el sistema acepta el archivo o lo deja accesible después

### Cómo reproducirlo con comandos

Ejemplo orientativo con `multipart/form-data`:

```bash
curl -i -X POST "http://DVWA_DOMAIN/vulnerabilities/upload/" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low" \
  -F "uploaded=@./archivo-lab.txt;type=text/plain" \
  -F "Upload=Upload"
```

Para una prueba más realista, repite la carga cambiando extensión, nombre o `content-type`.

### Cómo verlo en F5 XC

- filtrar por `/vulnerabilities/upload/`
- revisar método `POST`, tamaño de request y tipo de contenido `multipart/form-data`
- validar si hay eventos por tamaño anómalo, tipo peligroso o firmas de payload malicioso
- comprobar si la política aplicó bloqueo, solo reporte o límites de tamaño

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

### Qué hace el ataque

CSRF aprovecha la sesión ya abierta de la víctima. El atacante no necesita robar la cookie; le basta con inducir al navegador autenticado a enviar una acción válida que la aplicación acepte sin un token o control adicional.

### Cómo reproducirlo desde la GUI

1. iniciar sesión en DVWA con una sesión válida
2. abrir `CSRF` y observar qué acción sensible ejecuta el formulario
3. cambiar un valor legítimo desde la propia GUI para identificar el request normal
4. construir una página o enlace externo que dispare la misma acción sin interacción consciente del usuario
5. visitar esa página con la sesión aún abierta y comprobar si el cambio se aplica

### Cómo reproducirlo con comandos

Ejemplo orientativo para un cambio directo de contraseña en `Low`:

```bash
curl -i -G "http://DVWA_DOMAIN/vulnerabilities/csrf/" \
  --data-urlencode "password_new=LabPass123!" \
  --data-urlencode "password_conf=LabPass123!" \
  --data-urlencode "Change=Change" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low"
```

### Cómo verlo en F5 XC

- buscar el path `/vulnerabilities/csrf/`
- revisar si la acción sensible llega como request aparentemente legítimo desde una sesión ya autenticada
- comprobar `Referer`, `Origin`, método y repetición del flujo
- recordar que F5 XC puede dar contexto y controles compensatorios, pero no sustituye tokens CSRF del lado de la aplicación

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

### Qué hace el ataque

Este módulo demuestra que un CAPTCHA débil o mal integrado no frena realmente la automatización. El atacante intenta repetir el flujo, reutilizar valores o saltarse pasos sin resolver un desafío robusto.

### Cómo reproducirlo desde la GUI

1. abrir `Insecure CAPTCHA`
2. completar el flujo una vez de forma normal para entender qué campos usa
3. repetir el proceso varias veces observando si el reto cambia de verdad o si puede reutilizarse
4. probar si el flujo puede completarse con pasos mínimos o repeticiones mecánicas

### Cómo reproducirlo con comandos

Aquí suele ser más fiable capturar el request exacto desde `Network` y repetirlo con `curl`. Lo importante no es un payload concreto, sino verificar si el flujo acepta automatización simple o replay con la misma sesión.

Patrón orientativo:

```bash
curl -i -X POST "http://DVWA_DOMAIN/vulnerabilities/captcha/" \
  -H "Cookie: PHPSESSID=<SESSION>; security=low" \
  -d "<PARAMETROS_CAPTURADOS_DESDE_LA_GUI>"
```

### Cómo verlo en F5 XC

- revisar repetición de requests sobre `/vulnerabilities/captcha/`
- observar si el patrón es claramente automatizable por IP o fingerprint
- comprobar si Bot Defense o rate limiting ayudan a frenar el flujo
- comparar un uso humano aislado contra una secuencia rápida y repetitiva

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

### Qué hace el ataque

El problema aquí no es un payload en request, sino la previsibilidad del identificador. Si los IDs de sesión o del módulo siguen una secuencia fácil, un atacante puede intentar inferir los siguientes valores.

### Cómo reproducirlo desde la GUI

1. abrir `Weak Session IDs`
2. generar varios IDs o refrescar la función que los crea
3. apuntar los valores en orden
4. comprobar si siguen una secuencia incremental o un patrón reconocible

### Cómo reproducirlo con comandos

Puedes repetir el acceso varias veces y extraer el valor que devuelve la página:

```bash
for i in $(seq 1 10); do
  curl -s "http://DVWA_DOMAIN/vulnerabilities/weak_id/" \
    -H "Cookie: PHPSESSID=<SESSION>; security=low" \
    | grep -i "id"
done
```

Si la respuesta HTML cambia mucho, usa la GUI y DevTools para identificar exactamente qué valor debes observar.

### Cómo verlo en F5 XC

- F5 XC no corregirá la debilidad del generador de IDs
- sí puedes revisar repetición de accesos al módulo, IPs de origen y patrones de enumeración
- si el atacante prueba muchos IDs o automatiza accesos, analytics y controles L7 pueden mostrar el abuso secundario

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

### Qué hace el ataque

El open redirect toma un parámetro de destino y redirige al usuario sin validarlo bien. El riesgo no es solo la redirección, sino facilitar phishing, encadenar ataques o saltar controles de confianza.

### Cómo reproducirlo desde la GUI

1. abrir `Open Redirect`
2. identificar qué campo o parámetro define el destino
3. probar primero una ruta interna legítima
4. repetir con una URL externa del laboratorio
5. validar si DVWA redirige fuera del dominio esperado

### Cómo reproducirlo con comandos

Como el nombre del parámetro puede variar según la versión del módulo, lo más fiable es capturarlo en la GUI y repetirlo por CLI. Patrón orientativo:

```bash
curl -i -L "http://DVWA_DOMAIN/vulnerabilities/open_redirect/?<PARAM_DESTINO>=https://example.org"
```

Sustituye `<PARAM_DESTINO>` por el nombre real visto en `Network` o en el propio enlace generado por DVWA.

### Cómo verlo en F5 XC

- buscar el path `/vulnerabilities/open_redirect/`
- revisar el parámetro de destino y si contiene `http://` o `https://` externos
- validar si existen reglas por allowlist o bloqueo de dominios no permitidos
- correlacionar el evento con la respuesta `3xx` del backend o de la política

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

### Qué hace este tipo de problema

Aquí la vulnerabilidad vive principalmente en JavaScript del lado del cliente. El navegador toma datos, decide el flujo o actualiza el DOM sin suficientes controles, por lo que el backend puede ver muy poco del problema real.

### Cómo reproducirlo desde la GUI

1. abrir el módulo cliente correspondiente
2. usar DevTools para inspeccionar la URL, el DOM y el JavaScript
3. modificar parámetros, fragmentos o valores en formularios
4. comprobar si la lógica insegura ocurre sin que el servidor tenga contexto suficiente

### Cómo reproducirlo con comandos

Por CLI suele haber poca visibilidad útil porque `curl` no ejecuta JavaScript ni refleja cambios del DOM. Úsalo solo para verificar qué requests salen al backend; para el comportamiento vulnerable real, la GUI del navegador es la referencia principal.

### Cómo verlo en F5 XC

- revisar únicamente los requests que sí llegan al HTTP Load Balancer
- correlacionar esos eventos con lo que ves en DevTools del navegador
- asumir que F5 XC no observará fragmentos de URL ni manipulación DOM puramente local

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
  - `/vulnerabilities/brute/`
  - opcionalmente `/login.php` si también quieres proteger el acceso inicial a DVWA, separado de la prueba didáctica de brute force
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