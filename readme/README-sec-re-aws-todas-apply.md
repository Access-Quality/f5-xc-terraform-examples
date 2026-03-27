# Seguridad en RE para Arcadia + DVWA + Boutique + crAPI + Mailhog en AWS - Deploy

Este workflow despliega una solucion de **seguridad en el Regional Edge (RE) de F5 Distributed Cloud** para **cinco aplicaciones distintas alojadas en una sola instancia EC2 de AWS**:

- **Arcadia Finance**, publicada por `ARCADIA_DOMAIN`
- **DVWA**, publicada por `DVWA_DOMAIN`
- **Online Boutique**, publicada por `BOUTIQUE_DOMAIN`
- **crAPI**, publicada por `CRAPI_DOMAIN`
- **Mailhog**, publicada por `MAILHOG_DOMAIN`

Las cinco aplicaciones comparten la misma VM. Dentro de la instancia corre un **nginx instalado en el host** que enruta por `Host` hacia contenedores Docker publicados solo en `127.0.0.1`. En F5 XC se crea **un unico HTTP Load Balancer** que anuncia los cinco FQDN y apunta a un solo origin pool.

El caso esta pensado para demostrar, en una topologia simple y barata de operar, las siguientes capacidades:

- WAF global en el RE para trafico web y API
- API Discovery global sobre el load balancer compartido
- API Protection global en modo report usando specs de Arcadia y/o crAPI
- Bot Defense opcional sobre Arcadia en modo flag
- acceso publico a Mailhog para revisar el correo de laboratorio de crAPI
- Multiples aplicaciones expuestas por FQDN sin EKS ni Kubernetes
- Provisionamiento y destruccion completos con GitHub Actions + Terraform

---

## 1. Resumen ejecutivo

### Que despliega exactamente

El workflow crea tres capas desacopladas:

| Capa | Directorio | Funcion |
| --- | --- | --- |
| Infra AWS | `todas/infra` | VPC, subnet publica, internet gateway, rutas, security group y recursos base |
| VM compartida | `todas/vm` | EC2 + EIP + Docker + nginx + Arcadia + DVWA + Boutique + crAPI + Mailhog |
| Seguridad XC | `todas/xc` | Namespace, health check, origin pool, HTTP Load Balancer, WAF, API Security y Bot Defense |

### Que NO usa este caso

- No usa EKS
- No usa Customer Edge
- No usa AppConnect
- No usa routing por path como `/arcadia` o `/dvwa`
- No usa un load balancer distinto por aplicacion

### Por que esta arquitectura

La decision de usar **un solo origen**, **un solo nginx** y **un solo HTTP Load Balancer** simplifica el laboratorio y reduce puntos de falla. El enrutamiento por `Host` conserva mejor el comportamiento nativo de cada aplicacion que un path-based routing artificial.

---

## 2. Arquitectura final

### Flujo de trafico

```text
Cliente / Internet
        |
        | HTTP request con Host: arcadia|dvwa|boutique|crapi
        v
+---------------------------------------------------------------+
| F5 Distributed Cloud - Regional Edge                          |
|                                                               |
|  HTTP Load Balancer unico                                     |
|    - ARCADIA_DOMAIN                                           |
|    - DVWA_DOMAIN                                              |
|    - BOUTIQUE_DOMAIN                                          |
|    - CRAPI_DOMAIN                                             |
|                                                               |
|  Politicas posibles sobre el mismo LB:                        |
|    - WAF global                                               |
|    - API Discovery global                                     |
|    - API Protection global                                    |
|    - Bot Defense opcional para Arcadia                        |
+---------------------------------------------------------------+
                            |
                            | Origin pool -> Elastic IP del EC2 :80
                            v
+---------------------------------------------------------------+
| AWS EC2 Amazon Linux 2                                        |
|                                                               |
|  nginx en el host, escuchando en :80                          |
|    - server_name ARCADIA_DOMAIN  -> 127.0.0.1:18080/18081/... |
|    - server_name DVWA_DOMAIN     -> 127.0.0.1:18084           |
|    - server_name BOUTIQUE_DOMAIN -> 127.0.0.1:18085           |
|    - server_name CRAPI_DOMAIN    -> 127.0.0.1:18086           |
|    - server_name MAILHOG_DOMAIN  -> 127.0.0.1:18087           |
|                                                               |
|  Docker network: internal                                     |
|    - Arcadia containers                                       |
|    - DVWA container                                           |
|    - Boutique microservices                                   |
|    - crAPI services + Postgres + Mongo + Mailhog              |
+---------------------------------------------------------------+
```

### Razon tecnica de usar nginx en el host

El proxy ya no corre en un contenedor. Ahora se instala directamente en Amazon Linux 2 y escucha en el puerto `80` del host. Esto resuelve dos problemas operativos que aparecieron durante las pruebas:

- el health check de XC ya no depende de DNS interna de Docker
- el origin port consumido por XC queda fijo y estable en `80`

---

## 3. Aplicaciones publicadas

| Aplicacion | Dominio | URL base esperada | Uso principal |
| --- | --- | --- | --- |
| Arcadia Finance | `ARCADIA_DOMAIN` | `http://ARCADIA_DOMAIN/` | WAF, API Discovery, API Protection, Bot Defense |
| DVWA | `DVWA_DOMAIN` | `http://DVWA_DOMAIN/` | WAF, pruebas OWASP Web Top 10, brute force, injection |
| Online Boutique | `BOUTIQUE_DOMAIN` | `http://BOUTIQUE_DOMAIN/` | WAF, pruebas HTTP frontend, abuso y rate limiting |
| crAPI | `CRAPI_DOMAIN` | `http://CRAPI_DOMAIN/` | WAF, API Discovery, API Protection, pruebas OWASP API Top 10 |
| Mailhog | `MAILHOG_DOMAIN` | `http://MAILHOG_DOMAIN/` | Acceso web a los correos de laboratorio generados por crAPI |

### Rutas utiles por aplicacion

| Aplicacion | Rutas recomendadas |
| --- | --- |
| Arcadia | `/`, `/trading/login.php`, `/trading/auth.php`, `/api`, `/files`, `/app3` |
| DVWA | `/`, `/login.php`, `/setup.php`, `/vulnerabilities/brute/` |
| Boutique | `/` |
| crAPI | `/`, `/identity/api/auth/login`, `/workshop/api/`, `/community/api/` |
| Mailhog | `/` |

---

## 4. Topologia interna en la VM

El archivo `todas/vm/userdata.sh` instala Docker, instala nginx y levanta todos los servicios al arrancar la instancia.

### Puertos publicados localmente

Los contenedores no quedan expuestos a internet. Todos se publican solo hacia `127.0.0.1`:

| Servicio | Puerto local |
| --- | --- |
| Arcadia mainapp | `127.0.0.1:18080` |
| Arcadia backend | `127.0.0.1:18081` |
| Arcadia app2 | `127.0.0.1:18082` |
| Arcadia app3 | `127.0.0.1:18083` |
| DVWA | `127.0.0.1:18084` |
| Boutique frontend | `127.0.0.1:18085` |
| crAPI web | `127.0.0.1:18086` |
| Mailhog web | `127.0.0.1:18087` |

### Routing de nginx por host header

| Host recibido por nginx | Backend |
| --- | --- |
| `ARCADIA_DOMAIN` | Arcadia mainapp + subrutas `/files`, `/api`, `/app3` |
| `DVWA_DOMAIN` | DVWA |
| `BOUTIQUE_DOMAIN` | Boutique frontend |
| `CRAPI_DOMAIN` | crAPI web |
| `MAILHOG_DOMAIN` | Mailhog web |

### Health checks

Todos los `server` de nginx exponen `GET /healthz` con `HTTP 200`. Ademas existe un `default_server` que responde `200` en `/healthz` y `404` para el resto. XC usa ese endpoint para validar salud del origen.

---

## 5. Componentes de F5 XC

El modulo `todas/xc` crea los siguientes objetos principales:

| Objeto | Funcion |
| --- | --- |
| Namespace | Contenedor logico para objetos del caso |
| Health check | Verifica `GET /healthz` con `Host: ARCADIA_DOMAIN` |
| Origin pool | Apunta al Elastic IP del EC2 en el puerto `80` |
| HTTP Load Balancer | Publica los cinco dominios en el RE |
| App Firewall | WAF global del caso |
| API Definition | Solo se crea si hay una o mas specs cargadas |
| Bot Defense | Solo se inserta si `XC_BOT_DEFENSE=true` |

### Detalle del comportamiento de seguridad

#### WAF

- Siempre se adjunta al load balancer compartido
- El modo depende de `XC_WAF_BLOCKING`
- `false` = modo report / monitoreo
- `true` = modo bloqueo

#### API Discovery

- Se habilita con `XC_API_DISCOVERY=true`
- Aplica al LB compartido
- Permite aprender endpoints vistos en trafico
- Tiene sentido sobre todo para Arcadia y crAPI, aunque tecnicamente esta configurado a nivel del LB

#### API Protection

- Se habilita con `XC_API_PROTECTION=true`
- Solo se activa si existe al menos una spec cargada en XC
- Opera en **report mode**, no en bloqueo
- El workflow aborta si `XC_API_PROTECTION=true` pero no se cargo ninguna spec

#### Bot Defense

- Se habilita con `XC_BOT_DEFENSE=true`
- Se configura sobre Arcadia
- Protege `POST /trading/auth.php`
- La mitigacion usada es `flag`, no bloqueo

---

## 6. Workflows involucrados

| Workflow | Archivo | Objetivo |
| --- | --- | --- |
| Deploy | `.github/workflows/sec-re-aws-todas-apply.yml` | Crear AWS + VM + F5 XC + validaciones |
| Destroy | `.github/workflows/sec-re-aws-todas-destroy.yml` | Eliminar XC, luego VM, luego infra y limpiar specs |

### Orden del deploy

El workflow de deploy ejecuta tres jobs en cadena:

1. `terraform_infra`
2. `terraform_vm`
3. `terraform_xc`

### Orden del destroy

El workflow de destroy ejecuta el orden inverso:

1. `terraform_xc`
2. `terraform_vm`
3. `terraform_infra`

Ese orden evita que queden referencias vivas desde XC hacia un origen ya destruido.

---

## 7. Prerrequisitos operativos

Antes de lanzar el workflow, valida lo siguiente:

### GitHub Actions

- El repositorio debe tener habilitadas Actions
- Debes tener permisos para lanzar `workflow_dispatch`

### Terraform Cloud

Deben existir estos tres workspaces y estar en modo de ejecucion **Local**:

- `sec-re-aws-todas-infra`
- `sec-re-aws-todas-vm`
- `sec-re-aws-todas-xc`

Si un workspace esta en modo Remote, Terraform intentara ejecutar del lado de TFC y no heredara correctamente las variables del runner de GitHub Actions.

### DNS

Los cuatro FQDN deben resolver hacia el CNAME o VIP publica del HTTP Load Balancer de XC una vez creado. En la practica puedes trabajar de dos formas:

- precrear los registros DNS y luego apuntarlos al LB cuando ya exista el CNAME
- usar `/etc/hosts` temporalmente durante validacion local, si solo quieres probar desde una maquina concreta

### AWS

- La cuenta debe permitir crear VPC, subnet, route table, internet gateway, security group, key pair, EIP y EC2
- La AMI usada por el modulo VM debe estar disponible en la region elegida

### F5 XC

- Debes tener un tenant operativo
- Debes disponer del archivo `.p12` en base64 y su password
- El usuario del certificado debe tener permisos para crear namespace, object store objects y objetos de app delivery/security

---

## 8. Secrets requeridos

| Secret | Descripcion |
| --- | --- |
| `TF_API_TOKEN` | Token de Terraform Cloud |
| `TF_CLOUD_ORGANIZATION` | Nombre de la organizacion de Terraform Cloud |
| `AWS_ACCESS_KEY` | Access key de AWS |
| `AWS_SECRET_KEY` | Secret key de AWS |
| `XC_API_URL` | URL API del tenant de F5 XC, por ejemplo `https://tenant.console.ves.volterra.io/api` |
| `XC_P12_PASSWORD` | Password del certificado `.p12` |
| `XC_API_P12_FILE` | Archivo `.p12` codificado en base64 |
| `SSH_PRIVATE_KEY` | Llave privada desde la que se deriva la llave publica para la EC2 |

---

## 9. Variables requeridas

### Variables de infraestructura y dominios

| Variable | Ejemplo | Uso |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | Region de AWS para infra y VM |
| `PROJECT_PREFIX` | `sec-re-aws-todas` | Prefijo de recursos |
| `XC_NAMESPACE` | `democasos` | Namespace de F5 XC |
| `ARCADIA_DOMAIN` | `arcadia.example.com` | FQDN de Arcadia |
| `DVWA_DOMAIN` | `dvwa.example.com` | FQDN de DVWA |
| `BOUTIQUE_DOMAIN` | `boutique.example.com` | FQDN de Boutique |
| `CRAPI_DOMAIN` | `crapi.example.com` | FQDN de crAPI |
| `MAILHOG_DOMAIN` | `mailhog.example.com` | FQDN de Mailhog |

### Variables de seguridad

| Variable | Valores | Efecto |
| --- | --- | --- |
| `XC_WAF_BLOCKING` | `true` / `false` | Controla si el WAF bloquea o solo reporta |
| `XC_BOT_DEFENSE` | `true` / `false` | Activa Bot Defense en Arcadia login |
| `XC_API_DISCOVERY` | `true` / `false` | Activa API Discovery a nivel del LB |
| `XC_API_PROTECTION` | `true` / `false` | Activa API Protection global en modo report |
| `XC_UPLOAD_ARCADIA_API_SPEC` | `true` / `false` | Sube la spec OpenAPI de Arcadia al object store |
| `XC_UPLOAD_CRAPI_API_SPEC` | `true` / `false` | Sube la spec OpenAPI de crAPI al object store |

### Valores recomendados para el escenario acordado

Si quieres dejar el laboratorio alineado con el modelo mas seguro para pruebas sin romper trafico legitimo, usa:

| Variable | Valor recomendado |
| --- | --- |
| `XC_WAF_BLOCKING` | `false` |
| `XC_BOT_DEFENSE` | `true` |
| `XC_API_DISCOVERY` | `true` |
| `XC_API_PROTECTION` | `true` |
| `XC_UPLOAD_ARCADIA_API_SPEC` | `true` |
| `XC_UPLOAD_CRAPI_API_SPEC` | `true` |

---

## 10. Matriz de comportamiento de variables

Esta es la parte importante del workflow actual.

| `XC_API_DISCOVERY` | `XC_API_PROTECTION` | Specs cargadas | Resultado |
| --- | --- | --- | --- |
| `false` | `false` | ninguna | Solo WAF global, sin API Security |
| `true` | `false` | ninguna o algunas | API Discovery habilitado, sin validacion de spec |
| `true` | `true` | una o mas | API Discovery + API Protection en report |
| `false` | `true` | ninguna | Error, el workflow se detiene |
| `false` | `true` | una o mas | API Protection en report sin Discovery |

### Regla operativa importante

Si `XC_API_PROTECTION=true`, al menos una de estas debe ser `true`:

- `XC_UPLOAD_ARCADIA_API_SPEC`
- `XC_UPLOAD_CRAPI_API_SPEC`

Si ambas estan en `false`, el job `terraform_xc` falla a proposito antes de aplicar Terraform.

---

## 11. Specs OpenAPI usadas por el workflow

El workflow puede subir automaticamente dos specs al object store de XC:

| Aplicacion | Nombre del objeto en XC | Fuente |
| --- | --- | --- |
| Arcadia | `arcadia-oas3` | `arcadia/arcadia-oas3-2.0.1.json` descargada desde GitHub |
| crAPI | `crapi-openapi` | `https://raw.githubusercontent.com/OWASP/crAPI/develop/openapi-spec/crapi-openapi-spec.json` |

### Que hace el apply con esas specs

1. Descarga la spec
2. Limpia claves vacias del JSON
3. La sube al object store de XC
4. Recupera la URL interna generada por XC
5. Construye `TF_VAR_xc_api_specs` con una lista JSON
6. Terraform crea un `volterra_api_definition` solo si la lista tiene contenido

### Que hace el destroy con esas specs

El destroy intenta borrar siempre ambos objetos:

- `arcadia-oas3`
- `crapi-openapi`

Si alguno no existe, un `404` se considera aceptable.

---

## 12. Secuencia exacta del workflow de deploy

### Job 1: `terraform_infra`

Ubicacion: `todas/infra`

Acciones:

1. checkout del repo
2. configuracion de Terraform CLI
3. generacion de `backend.tf` para `sec-re-aws-todas-infra`
4. `terraform init`
5. `terraform validate`
6. `terraform apply`

Resultado esperado:

- VPC lista
- subnet publica lista
- security group listo
- recursos base exportados a remote state

### Job 2: `terraform_vm`

Ubicacion: `todas/vm`

Acciones:

1. checkout del repo
2. configuracion de Terraform CLI
3. extraccion de la llave publica desde `SSH_PRIVATE_KEY`
4. generacion de `backend.tf` para `sec-re-aws-todas-vm`
5. `terraform init`
6. `terraform validate`
7. `terraform apply`
8. espera activa hasta validar el origen por Elastic IP y host header

Validaciones que hace este job antes de continuar:

- `GET /healthz` con `Host: ARCADIA_DOMAIN` -> `200`
- `GET /` con `Host: ARCADIA_DOMAIN` -> `200`
- `GET /` con `Host: DVWA_DOMAIN` -> `200`, `301` o `302`
- `GET /` con `Host: BOUTIQUE_DOMAIN` -> `200`
- `GET /` con `Host: CRAPI_DOMAIN` -> `200`
- `GET /` con `Host: MAILHOG_DOMAIN` -> `200`

### Job 3: `terraform_xc`

Ubicacion: `todas/xc`

Acciones:

1. checkout del repo
2. configuracion de Terraform CLI
3. generacion de `backend.tf` para `sec-re-aws-todas-xc`
4. decodificacion del `.p12`
5. creacion del namespace si no existe
6. upload opcional de spec Arcadia
7. upload opcional de spec crAPI
8. construccion de `TF_VAR_xc_api_specs`
9. `terraform init`
10. `terraform validate`
11. `terraform state rm volterra_namespace.this` si existe en state
12. `terraform apply`
13. espera activa contra endpoints publicos

Validaciones publicas finales:

- `http://ARCADIA_DOMAIN/` -> `200`
- `http://DVWA_DOMAIN/` -> `200`, `301` o `302`
- `http://BOUTIQUE_DOMAIN/` -> `200`
- `http://CRAPI_DOMAIN/` -> `200`
- `http://MAILHOG_DOMAIN/` -> `200`

---

## 13. Secuencia exacta del workflow de destroy

### Job 1: `terraform_xc`

1. `terraform destroy` en `todas/xc`
2. borrado de specs del object store
3. borrado del namespace XC

### Job 2: `terraform_vm`

1. `terraform destroy` en `todas/vm`

### Job 3: `terraform_infra`

1. `terraform destroy` en `todas/infra`

### Consideracion de permisos

Si el usuario del `.p12` no puede borrar namespaces, el workflow deja una advertencia y te indica borrarlo manualmente desde la consola de F5 XC.

---

## 14. Como ejecutar el deploy

### Desde GitHub Actions

1. Ir a **Actions**
2. Seleccionar `Seguridad en RE para Arcadia + DVWA + Boutique + crAPI + Mailhog en AWS - Deploy`
3. Ejecutar `Run workflow`
4. Esperar a que finalicen los tres jobs
5. Revisar el job `terraform_xc` para obtener confirmacion de que los endpoints publicos responden

### Señales de que el deploy quedo bien

- `terraform_infra` termina en verde
- `terraform_vm` termina en verde y las esperas de origen pasan
- `terraform_xc` termina en verde y las esperas publicas pasan
- las cinco aplicaciones responden desde internet por su FQDN

---

## 15. Como validar manualmente despues del deploy

### Validacion del origen directo

Usa el Elastic IP de la VM con `Host` explicito:

```bash
curl -i -H "Host: ${ARCADIA_DOMAIN}"  http://<VM_IP>/
curl -i -H "Host: ${DVWA_DOMAIN}"     http://<VM_IP>/
curl -i -H "Host: ${BOUTIQUE_DOMAIN}" http://<VM_IP>/
curl -i -H "Host: ${CRAPI_DOMAIN}"    http://<VM_IP>/
curl -i -H "Host: ${MAILHOG_DOMAIN}"  http://<VM_IP>/
```

### Validacion publica via XC

```bash
curl -i http://${ARCADIA_DOMAIN}/
curl -i http://${DVWA_DOMAIN}/
curl -i http://${BOUTIQUE_DOMAIN}/
curl -i http://${CRAPI_DOMAIN}/
curl -i http://${MAILHOG_DOMAIN}/
```

### Validacion de health checks

```bash
curl -i -H "Host: ${ARCADIA_DOMAIN}" http://<VM_IP>/healthz
curl -i -H "Host: ${DVWA_DOMAIN}" http://<VM_IP>/healthz
curl -i -H "Host: ${BOUTIQUE_DOMAIN}" http://<VM_IP>/healthz
curl -i -H "Host: ${CRAPI_DOMAIN}" http://<VM_IP>/healthz
curl -i -H "Host: ${MAILHOG_DOMAIN}" http://<VM_IP>/healthz
```

### Validacion de API Protection en modo report

Si activaste API Discovery y API Protection, revisa en F5 XC:

- endpoints descubiertos
- eventos de validacion de schema
- observaciones o violaciones reportadas

Como la politica esta en report, no deberias esperar bloqueos por schema mismatch salvo que luego cambies la politica.

---

## 16. Pruebas de seguridad sugeridas

### Arcadia

Casos sugeridos:

- login normal y login automatizado
- descubrimiento de endpoints API
- envio de payloads malformed en query params o body
- revision de eventos de Bot Defense sobre `POST /trading/auth.php`

Guia detallada:

- [Pruebas de seguridad para Arcadia Finance](README-pruebas-arcadia.md)

### DVWA

Casos sugeridos:

- SQLi
- XSS
- command injection
- brute force sobre `GET /vulnerabilities/brute/`

Nota importante: para el modulo brute force de DVWA, una mitigacion de tipo **rate limiting** suele ser mas adecuada que una politica de **JS Challenge**.

Guia detallada:

- [Pruebas de seguridad para DVWA](README-pruebas-dvwa.md)

### Online Boutique

Casos sugeridos:

- abuso de frontend HTTP
- rate limiting
- tests de WAF sobre parametros y requests anormalmente grandes

Guia detallada:

- [Pruebas de seguridad para Online Boutique](README-pruebas-boutique.md)

### crAPI

Casos sugeridos:

- inventario de endpoints con API Discovery
- validacion OpenAPI en modo report
- pruebas de BOLA / IDOR
- llamadas con token invalido o parametros no esperados

Guia detallada:

- [Pruebas de seguridad para crAPI](README-pruebas-crapi.md)

### Mailhog

Casos sugeridos:

- revisar correos generados por el flujo de recuperacion o activacion de crAPI
- validar que crAPI sigue resolviendo `mailhog-web:8025` internamente aunque ahora tambien exista acceso publico
- usar la UI web para inspeccionar mensajes sin entrar por SSH a la EC2

---

## 17. Troubleshooting detallado

### Caso: `terraform_vm` termina pero las apps no responden por origin

Revisar cloud-init y contenedores:

```bash
ssh -i <private_key> ec2-user@<VM_IP> "sudo cat /var/log/cloud-init-output.log"
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker ps"
ssh -i <private_key> ec2-user@<VM_IP> "sudo systemctl status nginx"
ssh -i <private_key> ec2-user@<VM_IP> "sudo nginx -t"
```

### Caso: origen responde pero XC devuelve `503`

Revisar estos puntos en orden:

1. que `todas/vm/outputs.tf` siga exportando `origin_port = 80`
2. que el health check en XC este pasando
3. que el EIP siga asociado a la VM correcta
4. que el `Host` del request coincida con uno de los dominios del LB

### Caso: Arcadia, DVWA y Boutique funcionan pero crAPI no

Revisar especificamente:

```bash
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker ps --format '{{.Names}} {{.Status}}'"
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker logs crapi-web --tail 100"
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker logs crapi-identity --tail 100"
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker logs crapi-community --tail 100"
ssh -i <private_key> ec2-user@<VM_IP> "sudo docker logs crapi-workshop --tail 100"
```

Tambien confirma que esten arriba:

- `postgresdb`
- `mongodb`
- `mailhog`
- `gateway-service`
- `crapi-identity`
- `crapi-community`
- `crapi-workshop`
- `crapi-web`

### Caso: `XC_API_PROTECTION=true` pero Terraform falla antes del apply

Eso es intencional si no hay specs cargadas. Corrige una de estas opciones:

- activa `XC_UPLOAD_ARCADIA_API_SPEC=true`
- activa `XC_UPLOAD_CRAPI_API_SPEC=true`
- o desactiva `XC_API_PROTECTION=false`

### Caso: el namespace ya existe

El workflow acepta `HTTP 409` al intentar crearlo. No necesitas borrar manualmente el namespace solo por ese motivo.

### Caso: el destroy no puede borrar el namespace

Si aparece `403`, el usuario del certificado no tiene permisos suficientes. El resto del destroy puede haber terminado correctamente; solo quedara pendiente borrar el namespace manualmente desde F5 XC.

### Caso: warnings en `todas/xc/waf.tf`

Actualmente el provider marca algunos argumentos como deprecados. Son warnings conocidos y no impiden `terraform validate` ni el deploy.

---

## 18. Archivos principales del caso

| Ruta | Uso |
| --- | --- |
| `todas/infra` | Infraestructura base de AWS |
| `todas/vm` | EC2, EIP y bootstrap de aplicaciones |
| `todas/vm/userdata.sh` | Instalacion de nginx y arranque de contenedores |
| `todas/vm/outputs.tf` | Exporta `vm_ip` y `origin_port=80` |
| `todas/xc` | Objetos de F5 XC |
| `todas/xc/loadbalancer.tf` | LB, origin pool, health check, API Security, Bot Defense |
| `todas/xc/waf.tf` | Politica WAF |
| `.github/workflows/sec-re-aws-todas-apply.yml` | Orquestacion del deploy |
| `.github/workflows/sec-re-aws-todas-destroy.yml` | Orquestacion del destroy |

---

## 19. URL publica de Mailhog

Una vez desplegado el cambio y configurado DNS, la URL esperada de Mailhog es:

- `http://MAILHOG_DOMAIN/`

Esto publica la interfaz web de Mailhog sin necesidad de SSH ni tuneles locales.

---

## 20. Recomendacion operativa final

Si tu objetivo es dejar este caso listo para demos, validacion funcional y pruebas controladas sin romper la navegacion legitima, la combinacion recomendada es:

- `XC_WAF_BLOCKING=false`
- `XC_BOT_DEFENSE=true`
- `XC_API_DISCOVERY=true`
- `XC_API_PROTECTION=true`
- `XC_UPLOAD_ARCADIA_API_SPEC=true`
- `XC_UPLOAD_CRAPI_API_SPEC=true`

Con esa combinacion obtienes:

- WAF en modo report
- Bot Defense en modo flag para Arcadia login
- Discovery de endpoints API
- Validacion de schema OpenAPI en modo report
- cobertura funcional sobre las cinco aplicaciones con un solo LB