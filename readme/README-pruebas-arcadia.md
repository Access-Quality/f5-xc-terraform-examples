# Pruebas de seguridad para Arcadia Finance y mitigacion con F5 DCS

## 1. Objetivo

Esta guia describe como ejecutar pruebas de seguridad sobre **Arcadia Finance** en el escenario publicado tras F5 Distributed Cloud Services, y como interpretar o mitigar los hallazgos con:

- **WAF** para payloads OWASP Top 10
- **API Discovery** para inventario de endpoints observados
- **API Protection** para validar el trafico contra la spec OpenAPI
- **Bot Defense** para detectar automatizacion y abuso de login

La intencion no es solo provocar eventos, sino distinguir claramente:

- que controla F5 XC en el edge
- que solo puede corregirse en backend o en la logica de negocio
- que pruebas deben ejecutarse en `report`, `flag` o `blocking`

---

## 2. Supuestos del laboratorio

Esta guia asume lo siguiente:

- Arcadia esta publicada por el dominio definido en `ARCADIA_DOMAIN`
- el login funciona en `http://<ARCADIA_DOMAIN>/trading/login.php`
- el usuario operativo es `matt`
- la contrasena operativa es `ilovef5`
- existe una politica de seguridad en F5 XC asociada al HTTP Load Balancer del escenario `todas`
- **WAF** puede estar en `monitor` o `blocking`
- **API Protection** normalmente esta en `report`
- **Bot Defense** normalmente esta en `flag`

Variables recomendadas para ejecutar los comandos:

```bash
export ARCADIA_DOMAIN="arcadia.digitalvs.com"
export ARC_BASE="http://${ARCADIA_DOMAIN}"
export ARC_COOKIE="/tmp/arcadia_cookie.txt"
```

---

## 3. Preparacion

### 3.1. Validar acceso a la UI

```bash
curl -I "${ARC_BASE}/trading/login.php"
```

Esperado:

- respuesta `200 OK` o redireccion valida
- cabeceras servidas por el frontend protegido

Si el sitio aun no responde, espera unos minutos y vuelve a intentar. Arcadia puede tardar en levantar tras el deploy.

### 3.2. Iniciar sesion y guardar cookie

```bash
curl -s -X POST "${ARC_BASE}/trading/auth.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=matt&password=ilovef5" \
  -c "${ARC_COOKIE}" \
  -D - | grep -i "location:"
```

Esperado:

- `location: index.php` indica login correcto

### 3.3. Verificar sesion funcional

```bash
curl -s "${ARC_BASE}/trading/rest/portfolio.php" \
  -b "${ARC_COOKIE}" | python3 -m json.tool

curl -s "${ARC_BASE}/api/side_bar_accounts.php" \
  -b "${ARC_COOKIE}" | python3 -m json.tool
```

Si esta parte falla, corrige primero la autenticacion antes de empezar pruebas ofensivas.

---

## 4. Que protege F5 XC y que no

### Lo que F5 XC si ayuda a mitigar

- SQL injection en query string, body o parametros JSON
- XSS reflejado o payloads activos detectables por firmas/politicas
- path traversal
- command injection basica
- abuso automatizado del login
- endpoints no documentados o trafico fuera de contrato OpenAPI
- clientes automatizados evidentes o user-agents de scanner

### Lo que F5 XC no arregla por si solo

- errores de autorizacion del backend
- BOLA o IDOR si la request es valida a nivel de schema y el backend no valida ownership
- logica de negocio insegura
- montos negativos, transferencias inconsistentes o reglas financieras defectuosas
- endpoints expuestos directamente por la IP publica del EC2 fuera del camino de F5 XC

---

## 5. Inventario de pruebas recomendadas

| Categoria | Ejemplo | Control primario |
| --- | --- | --- |
| Login y automatizacion | `POST /trading/auth.php` | Bot Defense, rate limiting |
| Descubrimiento de API | navegacion real de la UI | API Discovery |
| Payloads OWASP | SQLi, XSS, traversal, command injection | WAF |
| Desviaciones OpenAPI | tipos incorrectos, endpoint shadow | API Protection |
| BOLA / autorizacion | cambiar `account_id` u objetos referenciados | backend, observabilidad |
| Logica de negocio | montos negativos, valores extremos | backend, validacion de negocio |

---

## 6. Pruebas de autenticacion y abuso

## 6.1. Login legitimo

Usa primero el flujo normal para confirmar que el navegador y `curl` pueden autenticarse.

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "${ARC_BASE}/trading/auth.php" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=matt&password=ilovef5" -L
```

### Que revisar en F5 XC

- eventos asociados al endpoint `POST /trading/auth.php`
- clasificacion de Bot Defense si esta habilitado
- ausencia de bloqueos para el usuario legitimo

## 6.2. Credential stuffing o brute force controlado

```bash
for cred in "admin:admin" "admin:password" "matt:12345" "root:root" "guest:guest"; do
  user=$(echo "$cred" | cut -d: -f1)
  pass=$(echo "$cred" | cut -d: -f2)
  echo -n "$user:$pass -> "
  curl -s -o /dev/null -w "%{http_code}\n" -X POST \
    "${ARC_BASE}/trading/auth.php" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${user}&password=${pass}" -L
done
```

### Resultado esperado

- con Bot Defense en `flag`, las requests no necesariamente se bloquean, pero deben quedar observables
- con protecciones mas agresivas, deberias ver challenge, score de bot o bloqueo

### Mitigacion recomendada

- activar Bot Defense especificamente en el login
- complementar con rate limiting por IP, cookie o fingerprint
- si el demo rompe el flujo legitimo en `block`, mantener `flag` y usar los eventos para mostrar valor sin afectar UX

## 6.3. User-Agent de scanner

```bash
curl -i "${ARC_BASE}/" \
  -H "User-Agent: sqlmap/1.7.8#stable (https://sqlmap.org)"

curl -i "${ARC_BASE}/" \
  -H "User-Agent: Nikto/2.1.6"
```

### Resultado esperado

- Bot Defense o analitica de seguridad deberian registrar el cliente como sospechoso
- no siempre habra bloqueo si el modo es `flag`

---

## 7. API Discovery

Arcadia es un muy buen caso para mostrar valor de **API Discovery** porque mezcla UI clasica y endpoints consumidos por la propia interfaz.

### 7.1. Generar trafico real

Haz login desde navegador y navega por:

- dashboard
- portfolio
- transferencias
- tablas laterales y modales

Tambien puedes reforzarlo con `curl` autenticado:

```bash
curl -s "${ARC_BASE}/trading/rest/portfolio.php" -b "${ARC_COOKIE}" > /dev/null
curl -s "${ARC_BASE}/api/side_bar.php" -b "${ARC_COOKIE}" > /dev/null
curl -s "${ARC_BASE}/api/side_bar_accounts.php" -b "${ARC_COOKIE}" > /dev/null
curl -s "${ARC_BASE}/trading/transactions.php" -b "${ARC_COOKIE}" > /dev/null
```

### Que revisar en F5 XC

- endpoints descubiertos
- metodos HTTP observados
- rutas frecuentes frente a rutas raras
- posibles endpoints shadow o no documentados

### Valor operativo

API Discovery no bloquea por si solo. Su utilidad es:

- construir inventario real
- detectar rutas que la spec no contempla
- identificar superficie expuesta por la UI y por scripts

---

## 8. API Protection y OpenAPI

Arcadia ya tiene un caso conocido donde la UI real no encaja al 100% con la spec. Por eso hay que distinguir entre una prueba que demuestra control y una configuracion que rompe el demo.

## 8.1. Endpoint no documentado

```bash
curl -i "${ARC_BASE}/api/side_bar_table.php" \
  -b "${ARC_COOKIE}"
```

### Resultado esperado

- en `report`: deberia registrarse como endpoint no documentado
- en `block`: la UI puede romperse porque ese endpoint participa en el flujo real

### Mitigacion recomendada

- actualizar la spec OpenAPI para reflejar el comportamiento real
- o excluir temporalmente ese endpoint de enforcement si el objetivo es mantener la demo funcional

## 8.2. Tipo de dato no conforme al schema

```bash
curl -i -X POST "${ARC_BASE}/api/rest/execute_money_transfer.php" \
  -H "Content-Type: application/json" \
  -b "${ARC_COOKIE}" \
  -d '{"amount":"1000","account":"2"}'
```

### Resultado esperado

- en `report`: violacion de schema si la spec define enteros y el body envia strings
- en `block`: posible `403` por schema mismatch

### Mitigacion recomendada

- corregir el frontend para enviar enteros reales
- o ajustar la spec si el backend acepta strings por compatibilidad

## 8.3. Campo inesperado o body fuera de contrato

```bash
curl -i -X POST "${ARC_BASE}/api/rest/execute_money_transfer.php" \
  -H "Content-Type: application/json" \
  -b "${ARC_COOKIE}" \
  -d '{"amount":1000,"account":2,"debug":true,"unexpected":"value"}'
```

### Que demuestra esta prueba

- API Protection ayuda a detectar cuerpos fuera de contrato
- esto no sustituye validaciones de negocio, pero endurece el borde y reduce superficie inesperada

---

## 9. WAF sobre payloads clasicos

Estas pruebas tienen mas valor cuando el WAF esta en `blocking`. Si esta en `monitor`, espera eventos pero no bloqueos.

## 9.1. SQL injection en JSON body

```bash
curl -i -X POST "${ARC_BASE}/api/rest/execute_money_transfer.php" \
  -H "Content-Type: application/json" \
  -d '{"amount":1000,"to":"anna'\'' OR '\''1'\''='\''1"}'
```

Esperado con bloqueo:

- `Request Rejected`
- cabecera `server: volt-adc`
- `support ID`

## 9.2. SQLi union-based sobre campo numerico

```bash
curl -i -X POST "${ARC_BASE}/api/rest/execute_money_transfer.php" \
  -H "Content-Type: application/json" \
  -d '{"amount":"1 UNION SELECT username,password FROM users--","to":"Bart"}'
```

## 9.3. XSS en body JSON

```bash
curl -i -X POST "${ARC_BASE}/api/rest/execute_money_transfer.php" \
  -H "Content-Type: application/json" \
  -d '{"amount":100,"to":"<script>alert(1)</script>"}'
```

## 9.4. Path traversal

```bash
curl -i "${ARC_BASE}/../../../../etc/passwd"
curl -i "${ARC_BASE}/api/lower_bar.php?file=../../../../etc/passwd"
```

## 9.5. Command injection en query string

```bash
curl -i "${ARC_BASE}/api/lower_bar.php?user=admin;id"
```

### Mitigacion esperada

- WAF detecta y bloquea patrones conocidos
- si alguna variante no se detecta, ajusta la politica o añade reglas complementarias

---

## 10. BOLA, IDOR y autorizacion

Estas pruebas son importantes porque muestran el limite de un control de borde frente a una falla de logica o autorizacion.

## 10.1. Manipular identificador de cuenta

```bash
curl -i -b "${ARC_COOKIE}" \
  "${ARC_BASE}/api/side_bar_accounts.php?account_id=1"
```

### Interpretacion

- si el backend devuelve informacion de una cuenta ajena, tienes una BOLA/IDOR real
- WAF o API Protection no siempre bloquearan esto si el request es sintacticamente valido

### Mitigacion real

- validar ownership del objeto en backend
- no confiar en IDs aportados por el cliente
- usar controles de autorizacion por recurso

## 10.2. Cambio de parametros validos pero no autorizados

Prueba variaciones sobre IDs, cuentas destino o recursos internos siempre autenticado con un usuario legitimo.

### Leccion clave

F5 XC mejora observabilidad y reduce abuso obvio, pero **no sustituye autorizacion a nivel de aplicacion**.

---

## 11. Logica de negocio

## 11.1. Montos negativos o extremos

```bash
curl -i -b "${ARC_COOKIE}" -X POST \
  "${ARC_BASE}/trading/rest/buy_stocks.php" \
  -H "Content-Type: application/json" \
  -d '{"trans_value":-99999,"stock_price":198,"qty":1,"company":"F5"}'
```

## 11.2. Valores absurdos o desbordados

```bash
curl -i -b "${ARC_COOKIE}" -X POST \
  "${ARC_BASE}/trading/rest/buy_stocks.php" \
  -H "Content-Type: application/json" \
  -d '{"trans_value":999999999,"stock_price":0.00001,"qty":999999,"company":"F5"}'
```

### Interpretacion

- si el backend acepta operaciones financieramente absurdas, es una falla de negocio
- el WAF puede no bloquear porque la request puede ser perfectamente valida desde el punto de vista sintactico

### Mitigacion real

- validaciones server-side de rangos
- reglas de negocio estrictas
- confirmaciones transaccionales
- auditoria y antifraude aguas abajo

---

## 12. Comparativa por tipo de control

| Prueba | WAF | API Discovery | API Protection | Bot Defense | Backend |
| --- | --- | --- | --- | --- | --- |
| SQLi | Alta | Baja | Media | Baja | Media |
| XSS | Alta | Baja | Baja | Baja | Media |
| Path traversal | Alta | Baja | Baja | Baja | Media |
| Command injection | Alta | Baja | Baja | Baja | Alta |
| Credential stuffing | Baja | Baja | Baja | Alta | Media |
| Endpoint shadow | Baja | Media | Alta | Baja | Media |
| Schema mismatch | Baja | Baja | Alta | Baja | Media |
| BOLA / IDOR | Baja | Baja | Baja a media | Baja | Alta |
| Logica de negocio | Baja | Baja | Baja | Baja | Muy alta |

---

## 13. Secuencia recomendada de demo

Si quieres mostrar el valor de Arcadia en una sesion tecnica o comercial, ejecuta este orden:

1. login legitimo
2. navegacion real para poblar API Discovery
3. prueba de endpoint no documentado en `report`
4. schema mismatch contra `execute_money_transfer.php`
5. SQLi o XSS con WAF en `blocking`
6. scanner user-agent o brute force controlado para Bot Defense
7. ejemplo de BOLA o negocio inseguro para explicar el limite del edge

Este orden cuenta una historia tecnica coherente:

- primero funcionalidad real
- luego observabilidad
- luego enforcement contra payloads conocidos
- finalmente limitaciones que requieren hardening de la aplicacion

---

## 14. Que revisar en F5 XC despues de cada prueba

- `Security Events` para ver bloqueos, firmas y support IDs
- eventos de Bot Defense sobre `POST /trading/auth.php`
- hallazgos de API Discovery
- violaciones de API Protection por schema, metodo o endpoint shadow
- diferencia entre requests via dominio protegido y acceso directo a la Elastic IP

Si pruebas directamente contra la IP publica del EC2 en `:8080`, recuerda que eso evita el camino protegido y no representa la eficacia del control en el edge.

---

## 15. Mitigaciones recomendadas

### Mitigaciones en F5 XC

- mantener WAF en `monitor` mientras afinas falsos positivos y luego mover a `blocking`
- usar API Discovery para construir el inventario real antes de endurecer enforcement
- corregir o ampliar la spec OpenAPI y despues endurecer API Protection
- aplicar Bot Defense y rate limiting especificamente en el login

### Mitigaciones en la aplicacion

- validar ownership de cuentas y objetos
- corregir reglas de negocio para montos, cantidades y transferencias
- reducir exposicion directa del EC2 para evitar bypass del edge
- usar validacion estricta server-side aunque exista WAF

### Mitigaciones de arquitectura

- eliminar acceso publico directo al backend
- mover la app a subred privada si quieres forzar paso por F5 XC
- usar AppConnect o un patron equivalente cuando el objetivo sea inspeccion obligatoria

---

## 16. Conclusiones

Arcadia es uno de los mejores casos del laboratorio para demostrar la combinacion de controles de F5 DCS porque mezcla:

- login web clasico
- endpoints API accesibles desde la UI
- una spec OpenAPI util pero imperfecta
- casos claros de WAF, API Discovery, API Protection y Bot Defense

La lectura correcta del resultado es esta:

- **WAF** sirve muy bien para payloads clasicos y abuso evidente
- **API Discovery** aporta visibilidad real de la superficie expuesta
- **API Protection** ayuda a detectar desviaciones respecto al contrato
- **Bot Defense** es util para automatizacion y abuso de login
- **backend y arquitectura** siguen siendo responsables de autorizacion, negocio y eliminacion de bypasses

Si una prueba pasa aunque el request atraveso F5 XC, no siempre significa que el control fallo. Puede significar que estas ante un problema que solo se corrige en la aplicacion o en la arquitectura.