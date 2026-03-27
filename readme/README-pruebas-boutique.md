# Pruebas de seguridad para Online Boutique y mitigacion con F5 DCS

## 1. Objetivo

Esta guia describe como ejecutar pruebas de seguridad sobre **Online Boutique** en el escenario compartido `todas`, y como interpretar los resultados con foco en:

- **WAF** para payloads web clasicos
- **rate limiting** para abuso repetitivo y flood HTTP
- **Bot Defense** como capa opcional contra automatizacion del frontend
- limites reales de F5 XC cuando el problema esta en la logica de negocio o en servicios internos

Online Boutique **no es un caso principal de API Security** en este laboratorio. La aplicacion publica solo el `frontend` HTTP y los demas microservicios se comunican internamente. Por eso aqui el valor esta sobre todo en el borde web y no en API Discovery / API Protection.

---

## 2. Supuestos del laboratorio

Esta guia asume lo siguiente:

- la aplicacion responde en `http://<BOUTIQUE_DOMAIN>/`
- el trafico entra por F5 Distributed Cloud
- el escenario usa el dominio configurado en `BOUTIQUE_DOMAIN`
- puedes usar `curl` desde tu equipo para generar requests contra el frontend
- si aplicas pruebas de carga, entiendes que podrías disparar rate limiting sobre tu propia IP publica

Variables recomendadas:

```bash
export BOUTIQUE_DOMAIN="boutique.digitalvs.com"
export BOUTIQUE_BASE="http://${BOUTIQUE_DOMAIN}"
export BOUTIQUE_COOKIE="/tmp/boutique_cookie.txt"
```

---

## 3. Entender la superficie expuesta

En Online Boutique, el exterior solo ve el `frontend` HTTP. La aplicacion genera HTML y formularios que luego invocan acciones del mismo frontend. En una inspeccion simple del sitio se observan estas rutas reales:

- `GET /`
- `GET /cart`
- `GET /product/<product_id>`
- `POST /setCurrency`
- `POST /cart`
- `POST /cart/empty`
- `POST /cart/checkout`

Esto es importante porque evita una expectativa incorrecta: no estas protegiendo una API REST publica estilo crAPI o Arcadia, sino una aplicacion web con formularios y parametros HTTP.

---

## 4. Preparacion

### 4.1. Validar acceso basico

```bash
curl -I "${BOUTIQUE_BASE}/"
curl -I "${BOUTIQUE_BASE}/cart"
curl -I "${BOUTIQUE_BASE}/product/OLJCESPC7Z"
```

Esperado:

- respuestas `200 OK`
- HTML normal del frontend

### 4.2. Crear una sesion basica y agregar un producto al carrito

```bash
rm -f "${BOUTIQUE_COOKIE}"

curl -s -c "${BOUTIQUE_COOKIE}" -b "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart" \
  -d "product_id=OLJCESPC7Z&quantity=1" \
  -o /dev/null

curl -s -L -b "${BOUTIQUE_COOKIE}" "${BOUTIQUE_BASE}/cart" | head
```

Con esto ya puedes probar flujos reales sobre carrito y checkout.

### 4.3. Cambiar moneda

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/setCurrency" \
  -d "currency_code=EUR"
```

Esto sirve para validar requests POST normales antes de empezar a mutarlas.

---

## 5. Que protege F5 XC y que no

### Lo que F5 XC si ayuda a mitigar bien aqui

- payloads XSS reflejados en query string o formulario
- SQLi generica aunque el backend real no sea un SQL clasico visible
- path traversal y command injection en parametros web
- bursts repetitivos al frontend
- floods HTTP L7
- user-agents de scanner y automatizacion evidente
- requests anormalmente grandes o patrones de abuso volumetrico cuando la politica esta ajustada

### Lo que F5 XC no arregla por si solo

- errores de negocio en checkout
- validaciones funcionales pobres del carrito
- fraude de compra o abuso semantico si la request es sintacticamente valida
- fallas internas entre microservicios gRPC
- problemas de inventario, precios o estado de orden si el backend los acepta logicamente

---

## 6. Inventario de pruebas recomendadas

| Categoria | Endpoint o flujo | Control primario |
| --- | --- | --- |
| Frontend basico | `GET /`, `GET /product/<id>` | WAF |
| Formularios | `POST /cart`, `POST /setCurrency`, `POST /cart/checkout` | WAF, Bot Defense opcional |
| Carga repetitiva | `GET /`, `GET /cart` | rate limiting |
| Scanner / scraping | user-agents y navegacion automatizada | Bot Defense, rate limiting |
| Requests grandes | checkout con campos sobredimensionados | WAF, limites HTTP |
| Logica de negocio | cantidades, checkout, datos de orden | backend |

---

## 7. Rutas y parametros reales observados

Durante la inspeccion del frontend se observaron estos parametros:

### `POST /setCurrency`

- `currency_code`

### `POST /cart`

- `product_id`
- `quantity`

### `POST /cart/checkout`

- `email`
- `street_address`
- `zip_code`
- `city`
- `state`
- `country`
- `credit_card_number`
- `credit_card_expiration_month`
- `credit_card_expiration_year`
- `credit_card_cvv`

Esto permite probar el frontend con bastante precision sin necesidad de inventar endpoints.

---

## 8. Pruebas WAF sobre el frontend

Estas pruebas tienen mas valor con la politica en `blocking`. Si el WAF esta en `monitor`, espera eventos pero no bloqueos.

## 8.1. XSS en query string

```bash
curl -i "${BOUTIQUE_BASE}/?x=<script>alert(1)</script>"
```

### Esperado

- con bloqueo: `Request Rejected`, `server: volt-adc` o respuesta equivalente de denegacion
- con monitoreo: evento de seguridad sin bloqueo

## 8.2. SQLi en query string

```bash
curl -i "${BOUTIQUE_BASE}/?id=1'+OR+'1'='1"
```

## 8.3. Path traversal

```bash
curl -i "${BOUTIQUE_BASE}/../../etc/passwd"
```

## 8.4. Command injection por query param

```bash
curl -i "${BOUTIQUE_BASE}/?cmd=;cat+/etc/passwd"
```

### Lectura correcta

Aunque Boutique no exponga una API publica rica, el WAF sigue teniendo valor porque inspecciona el trafico HTTP del frontend y frena payloads obvios antes de llegar a la aplicacion.

---

## 9. Pruebas sobre formularios reales

## 9.1. `POST /cart` con cantidad anomala

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart" \
  -d "product_id=OLJCESPC7Z&quantity=-999"
```

### Interpretacion

- si el frontend o backend aceptan cantidades negativas, es una falla de logica
- el WAF podria no bloquear si la request no coincide con una firma de ataque clasica

## 9.2. `POST /cart` con payload XSS o SQLi en `product_id`

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart" \
  -d "product_id=<script>alert(1)</script>&quantity=1"

curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart" \
  -d "product_id=1'+OR+'1'='1&quantity=1"
```

### Valor de esta prueba

- demuestra inspeccion de payloads dentro del body de formulario
- sirve para validar WAF aunque el backend no use esos campos como una base SQL literal

## 9.3. `POST /setCurrency` con valor fuera de lista

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/setCurrency" \
  -d "currency_code=<script>alert(1)</script>"
```

### Interpretacion

- si se bloquea, el WAF esta inspeccionando correctamente el cuerpo del formulario
- si no se bloquea y la app ignora el valor, puede no haber impacto real pero sigue siendo util como prueba de observabilidad

---

## 10. Checkout: abuse testing y limites del edge

Primero llena un carrito y luego prueba el checkout.

## 10.1. Checkout nominal

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart/checkout" \
  -d "email=test@example.com" \
  -d "street_address=Av+Demo+123" \
  -d "zip_code=01010" \
  -d "city=CDMX" \
  -d "state=CDMX" \
  -d "country=Mexico" \
  -d "credit_card_number=4444444444444444" \
  -d "credit_card_expiration_month=12" \
  -d "credit_card_expiration_year=2030" \
  -d "credit_card_cvv=123"
```

Esto no se usa para comprar nada real. Solo sirve para verificar que el flujo HTML funciona antes de mutar valores.

## 10.2. Campos sobredimensionados

```bash
LONG_VALUE=$(printf 'A%.0s' {1..5000})

curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart/checkout" \
  -d "email=test@example.com" \
  -d "street_address=${LONG_VALUE}" \
  -d "zip_code=01010" \
  -d "city=CDMX" \
  -d "state=CDMX" \
  -d "country=Mexico" \
  -d "credit_card_number=4444444444444444" \
  -d "credit_card_expiration_month=12" \
  -d "credit_card_expiration_year=2030" \
  -d "credit_card_cvv=123"
```

### Que demuestra

- si existen limites HTTP o reglas contra requests anormalmente grandes
- si el frontend/backend degrada o acepta datos absurdamente grandes

## 10.3. Payloads activos dentro del checkout

```bash
curl -i -b "${BOUTIQUE_COOKIE}" -c "${BOUTIQUE_COOKIE}" \
  -X POST "${BOUTIQUE_BASE}/cart/checkout" \
  -d "email=test@example.com" \
  -d "street_address=<script>alert(1)</script>" \
  -d "zip_code=01010" \
  -d "city=CDMX" \
  -d "state=CDMX" \
  -d "country=Mexico" \
  -d "credit_card_number=4444444444444444" \
  -d "credit_card_expiration_month=12" \
  -d "credit_card_expiration_year=2030" \
  -d "credit_card_cvv=123"
```

### Interpretacion

- si el WAF bloquea, valida inspeccion de cuerpos URL-encoded
- si no bloquea y la app luego refleja el contenido, el problema puede convertirse en XSS persistente o reflejado segun el flujo

---

## 11. Rate limiting y DDoS L7

Boutique es especialmente buena para demostrar **rate limiting** y **L7 flood protection** porque el frontend es sencillo y muy sensible a bursts repetitivos.

## 11.1. Usar el script del repo

```bash
chmod +x herramientas/test_ddos.sh
./herramientas/test_ddos.sh "${BOUTIQUE_BASE}"
```

El script cubre tres pruebas:

- burst de requests para rate limit
- flood HTTP L7
- abuso repetitivo con User-Agent sospechoso

## 11.2. Burst manual simple

```bash
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}\n" "${BOUTIQUE_BASE}/" &
done
wait
```

### Resultado esperado

- sin rate limiting: muchos `200`
- con rate limiting: aparicion de `429` o `403`

## 11.3. Flood de frontend con `hey`

```bash
hey -n 300 -c 60 "${BOUTIQUE_BASE}/"
```

### Mitigacion esperada

- el sitio deberia seguir operativo
- el borde deberia absorber o limitar el burst
- F5 XC deberia registrar el comportamiento en eventos de seguridad

### Nota operativa

Rate limiting no siempre esta activo por defecto. Si el test no bloquea nada, puede significar simplemente que la politica no fue configurada aun.

---

## 12. Scanner simulation y automatizacion

## 12.1. User-Agent sospechoso

```bash
curl -i -A "sqlmap/1.0" "${BOUTIQUE_BASE}/"
curl -i -A "Nikto/2.1.6" "${BOUTIQUE_BASE}/"
```

## 12.2. Navegacion repetitiva a productos

```bash
for path in / /cart /product/OLJCESPC7Z /product/66VCHSJNUP /product/1YMWWN1N4O; do
  for i in $(seq 1 20); do
    curl -s -o /dev/null -w "%{http_code} ${path}\n" "${BOUTIQUE_BASE}${path}"
  done
done
```

### Interpretacion

- Bot Defense puede ayudar a etiquetar o frenar navegacion automatizada si se activa
- para este caso, **rate limiting suele ser la mitigacion mas directa y predecible**

---

## 13. Lo que no debes sobreinterpretar

Si una request de checkout o de carrito pasa a traves de F5 XC, eso **no prueba** que la aplicacion sea segura. Solo prueba que el borde no vio un patron bloqueable.

Ejemplos:

- una cantidad negativa aceptada es problema de negocio
- una compra con datos semanticamente absurdos es validacion deficiente del backend
- un flujo interno roto entre microservicios no lo arregla el WAF del frontend

La explicacion correcta al usuario o al cliente debe separar:

- proteccion del edge
- validacion de negocio
- integridad del sistema interno

---

## 14. Matriz de mitigacion

| Prueba | Mitigacion principal |
| --- | --- |
| XSS / SQLi / traversal / command injection en URL | WAF |
| Payloads maliciosos en formularios | WAF |
| Burst de requests al frontend | rate limiting |
| HTTP flood L7 | rate limiting y protecciones volumetricas |
| Scanner User-Agent | Bot Defense o firmas complementarias |
| Automatizacion repetitiva del frontend | rate limiting, Bot Defense opcional |
| Cantidades negativas o checkout incoherente | backend |
| Errores internos entre microservicios | backend / arquitectura |

---

## 15. Secuencia recomendada de demo

Si quieres mostrar el caso de Boutique en una demo tecnica, este orden funciona bien:

1. validar acceso a `/`
2. agregar un producto con `POST /cart`
3. mostrar `POST /setCurrency` legitimo
4. disparar XSS o SQLi simple en query string
5. probar payload malicioso en `POST /cart`
6. ejecutar burst o `test_ddos.sh`
7. cerrar explicando por que Boutique es mejor demo de WAF + rate limiting que de API Security

Este orden comunica bien el caso de uso real:

- frontend web publico
- formularios reales
- WAF para ataques clasicos
- rate limiting para abuso de navegacion y flood
- limites del edge frente a la logica interna

---

## 16. Que revisar en F5 XC

- `Security Events` para bloqueos WAF
- eventos asociados a bursts o `429`
- clasificaciones de clientes sospechosos si activas Bot Defense
- diferencia entre trafico normal de navegador y automatizacion por `curl`, `hey` o scripts

---

## 17. Mitigaciones recomendadas

### En F5 XC

- mantener WAF en `monitor` mientras ajustas falsos positivos y luego mover a `blocking`
- habilitar rate limiting en `/`, `/cart` y rutas de alto trafico si el objetivo es demostrar control frente a bursts
- usar Bot Defense solo si agrega valor al flujo, no como sustituto de rate limiting

### En la aplicacion

- validar server-side cantidades, checkout y datos de orden
- limitar tamanos de campos y formatos aceptados
- no confiar en que el WAF sustituye reglas funcionales del backend

### En la arquitectura

- mantener expuesto solo el frontend
- no publicar microservicios internos
- instrumentar logs y trazas del backend para correlacionar con eventos del edge

---

## 18. Conclusiones

Online Boutique es un caso fuerte para demostrar **proteccion web tradicional** en F5 DCS:

- WAF sobre payloads HTTP clasicos
- rate limiting frente a abuso repetitivo
- opcionalmente Bot Defense sobre navegacion automatizada

No es el mejor caso para hablar de API Discovery o API Protection porque la aplicacion no expone una API REST publica rica. Su valor didactico esta en otra parte:

- mostrar un frontend real con formularios observables
- probar bursts y flood L7
- separar claramente seguridad del edge de logica de negocio interna

Si Boutique resiste payloads web y empieza a devolver `429` bajo burst controlado, el caso ya esta demostrando bien el valor de F5 XC para aplicaciones frontend clasicas.