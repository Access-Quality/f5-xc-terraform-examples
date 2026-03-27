# Seguridad en RE para Arcadia + DVWA + Boutique + crAPI en AWS - Deploy con 4 LBs XC

Este workflow despliega una solucion de **seguridad en el Regional Edge (RE) de F5 Distributed Cloud** para **cuatro aplicaciones principales alojadas en una sola instancia EC2 de AWS**, sin nginx en la VM y con **cuatro HTTP Load Balancers en XC**:

- **Arcadia Finance**, publicada por `ARCADIA_DOMAIN`
- **DVWA**, publicada por `DVWA_DOMAIN`
- **Online Boutique**, publicada por `BOUTIQUE_DOMAIN`
- **crAPI**, publicada por `CRAPI_DOMAIN`
- **Mailhog**, publicada por `MAILHOG_DOMAIN` como interfaz web de apoyo para crAPI, compartiendo el mismo LB que crAPI

La idea central de este caso es separar el plano publico de XC por aplicacion, manteniendo al mismo tiempo **una sola VM compartida** en AWS:

- Arcadia usa su propio LB
- DVWA usa su propio LB
- Boutique usa su propio LB
- crAPI y Mailhog comparten un cuarto LB

## Guias relacionadas

- Guia rapida de pruebas: `readme/README-pruebas-todas-4lbs.md`
- Guia completa de pruebas: `readme/README-pruebas-todas-4lbs-completo.md`

## 1. Resumen ejecutivo

### Que despliega

El workflow crea tres capas desacopladas:

| Capa | Directorio | Funcion |
| --- | --- | --- |
| Infra AWS | `todas-4lbs/infra` | VPC, subnet publica, internet gateway, rutas, security group y recursos base |
| VM compartida | `todas-4lbs/vm` | EC2 + EIP + Docker + Arcadia + DVWA + Boutique + crAPI + Mailhog |
| Seguridad XC | `todas-4lbs/xc` | origin pools multiples, 4 HTTP Load Balancers, WAF, API Security y Bot Defense |

### Que NO usa este caso

- No usa EKS
- No usa Customer Edge
- No usa AppConnect
- No usa nginx en el host
- No usa un unico load balancer para todas las aplicaciones

### Cuadro tecnico del caso

Este caso es util cuando quieres un equilibrio entre aislamiento logico por aplicacion y simplicidad de infraestructura:

- una sola VM en AWS
- varios backends publicados por puerto
- varios LBs publicos en XC
- politica WAF comun reutilizada sobre los distintos LBs

## 2. Arquitectura final

### Flujo de trafico

```text
Cliente / Internet
        |
        | HTTP request con Host especifico por aplicacion
        v
+---------------------------------------------------------------+
| F5 Distributed Cloud - Regional Edge                          |
|                                                               |
|  HTTP Load Balancers dedicados                                |
|    - LB Arcadia   -> ARCADIA_DOMAIN                           |
|    - LB DVWA      -> DVWA_DOMAIN                              |
|    - LB Boutique  -> BOUTIQUE_DOMAIN                          |
|    - LB crAPI     -> CRAPI_DOMAIN + MAILHOG_DOMAIN            |
|                                                               |
|  Rutas en XC                                                  |
|    - LB Arcadia: /files, /api, /app3, /                       |
|    - LB DVWA: /                                               |
|    - LB Boutique: /                                           |
|    - LB crAPI: Host crapi -> crapi, Host mailhog -> mailhog   |
+---------------------------------------------------------------+
                            |
                            | varios origin pools -> misma Elastic IP, puertos distintos
                            v
+---------------------------------------------------------------+
| AWS EC2 Amazon Linux 2                                        |
|                                                               |
|  Sin nginx                                                    |
|                                                               |
|  Docker publica servicios directamente en el host             |
|    - 18080 Arcadia mainapp                                    |
|    - 18081 Arcadia files/backend                              |
|    - 18082 Arcadia api/app2                                   |
|    - 18083 Arcadia app3                                       |
|    - 18084 DVWA                                               |
|    - 18085 Boutique frontend                                  |
|    - 18086 crAPI web                                          |
|    - 18087 Mailhog web                                        |
+---------------------------------------------------------------+
```

## 3. Diferencia frente al caso sin nginx de LB unico

| Tema | Caso sin nginx | Caso 4 LBs |
| --- | --- | --- |
| nginx en VM | no | no |
| VM compartida | si | si |
| LBs en XC | 1 | 4 |
| Dominio de Mailhog | LB propio compartido con todos | compartido con crAPI |
| Aislamiento por aplicacion | bajo | mayor |
| Complejidad en XC | menor | mayor |

La diferencia principal es que ahora el enrutamiento y la exposicion publica quedan particionados por aplicacion. Eso permite:

- separar mejor la visibilidad operativa por aplicacion
- obtener un `cname` por LB si hace falta gestionar DNS por partes
- reducir el acoplamiento entre dominios sobre un solo objeto LB

## 4. Aplicaciones publicadas

| Aplicacion | Dominio | URL base esperada | Puerto origen | LB |
| --- | --- | --- | --- | --- |
| Arcadia Finance | `ARCADIA_DOMAIN` | `http://ARCADIA_DOMAIN/` | `18080` | Arcadia |
| Arcadia files | `ARCADIA_DOMAIN/files` | `http://ARCADIA_DOMAIN/files/` | `18081` | Arcadia |
| Arcadia api | `ARCADIA_DOMAIN/api` | `http://ARCADIA_DOMAIN/api/` | `18082` | Arcadia |
| Arcadia app3 | `ARCADIA_DOMAIN/app3` | `http://ARCADIA_DOMAIN/app3/` | `18083` | Arcadia |
| DVWA | `DVWA_DOMAIN` | `http://DVWA_DOMAIN/` | `18084` | DVWA |
| Online Boutique | `BOUTIQUE_DOMAIN` | `http://BOUTIQUE_DOMAIN/` | `18085` | Boutique |
| crAPI | `CRAPI_DOMAIN` | `http://CRAPI_DOMAIN/` | `18086` | crAPI |
| Mailhog | `MAILHOG_DOMAIN` | `http://MAILHOG_DOMAIN/` | `18087` | crAPI |

## 5. Componentes de F5 XC

El modulo `todas-4lbs/xc` crea los siguientes objetos principales:

| Objeto | Funcion |
| --- | --- |
| Namespace | Contenedor logico para objetos del caso |
| Health check | TCP health check comun para los origin pools |
| Origin pools | Un pool por backend o puerto expuesto |
| HTTP Load Balancers | Cuatro LBs: Arcadia, DVWA, Boutique y crAPI |
| App Firewall | WAF comun reutilizado por todos los LBs |
| API Definition | Solo se crea si hay una o mas specs cargadas |
| Bot Defense | Opcional; se adjunta solo al LB de Arcadia cuando esta habilitado |

### Distribucion de los LBs

| LB | Dominios | Backend por defecto | Rutas adicionales |
| --- | --- | --- | --- |
| Arcadia | `ARCADIA_DOMAIN` | `arcadia_main` | `/files`, `/api`, `/app3` |
| DVWA | `DVWA_DOMAIN` | `dvwa` | ninguna |
| Boutique | `BOUTIQUE_DOMAIN` | `boutique` | ninguna |
| crAPI | `CRAPI_DOMAIN`, `MAILHOG_DOMAIN` | `crapi` | `Host: MAILHOG_DOMAIN -> mailhog` |

### Seguridad aplicada

#### WAF

- Se adjunta a los cuatro load balancers
- El modo depende de `XC_WAF_BLOCKING`
- `false` = monitoreo
- `true` = bloqueo

#### API Discovery

- Se habilita con `XC_API_DISCOVERY=true`
- Se aplica solo a Arcadia y crAPI
- DVWA y Boutique quedan fuera para no consumir capacidad de validacion API donde no aporta valor real

#### API Protection

- Se habilita con `XC_API_PROTECTION=true`
- Solo se activa si existe al menos una spec cargada en XC
- Opera en modo report
- Se aplica solo a Arcadia y crAPI
- El workflow aborta si `XC_API_PROTECTION=true` pero no se cargo ninguna spec

#### Bot Defense

- Se habilita con `XC_BOT_DEFENSE=true`
- Se inserta solo en el LB de Arcadia
- La ruta configurada corresponde a `POST /trading/auth.php`, por lo que su utilidad real esta centrada en Arcadia

### Consideracion importante de limites en XC

Algunos tenants de F5 XC tienen limites bajos para `http_loadbalancer.oas_validation`. Por eso este caso restringe API Discovery y API Protection a **Arcadia** y **crAPI**, que son las aplicaciones donde realmente se aprovechan esas capacidades. Si intentas adjuntar validacion OpenAPI a los cuatro LBs, puedes agotar cuota del tenant y recibir errores `429` durante el `terraform apply`.

## 6. Workflows involucrados

| Workflow | Archivo | Objetivo |
| --- | --- | --- |
| Deploy | `.github/workflows/sec-re-aws-todas-4lbs.yml` | Crear AWS + VM sin nginx + 4 LBs en F5 XC + validaciones |
| Destroy | `.github/workflows/sec-re-aws-todas-4lbs-destroy.yml` | Eliminar XC, luego VM, luego infra y limpiar specs |

### Orden del deploy

1. `terraform_infra`
2. `terraform_vm`
3. `terraform_xc`

### Orden del destroy

1. `terraform_xc`
2. `terraform_vm`
3. `terraform_infra`

## 7. Terraform Cloud

Deben existir estos tres workspaces y estar en modo de ejecucion **Local**:

- `sec-re-aws-todas-4lbs-infra`
- `sec-re-aws-todas-4lbs-vm`
- `sec-re-aws-todas-4lbs-xc`

## 8. Outputs de Terraform XC y DNS esperado

El modulo `todas-4lbs/xc` exporta outputs utiles para DNS y validacion:

| Output | Tipo | Uso |
| --- | --- | --- |
| `xc_lb_name` | string | Nombre del LB de Arcadia, mantenido por compatibilidad |
| `xc_lb_names` | map | Nombre de cada LB por clave: `arcadia`, `dvwa`, `boutique`, `crapi` |
| `xc_waf_name` | string | Nombre de la politica WAF comun |
| `lb_domains` | map | Dominios asociados a cada LB |
| `lb_cname` | string | CNAME del LB de Arcadia, mantenido por compatibilidad |
| `lb_cnames` | map | CNAME de cada LB por clave: `arcadia`, `dvwa`, `boutique`, `crapi` |

### Mapa esperado de dominios a CNAME

Los valores concretos de `lb_cnames` los asigna F5 XC en tiempo de despliegue. Lo que debes esperar funcionalmente es este mapeo:

| Dominio publico | LB | CNAME esperado |
| --- | --- | --- |
| `ARCADIA_DOMAIN` | Arcadia | `lb_cnames.arcadia` |
| `DVWA_DOMAIN` | DVWA | `lb_cnames.dvwa` |
| `BOUTIQUE_DOMAIN` | Boutique | `lb_cnames.boutique` |
| `CRAPI_DOMAIN` | crAPI | `lb_cnames.crapi` |
| `MAILHOG_DOMAIN` | crAPI | `lb_cnames.crapi` |

### Implicacion operativa

- Arcadia, DVWA y Boutique pueden delegarse a registros DNS distintos porque cada uno tiene su propio CNAME
- crAPI y Mailhog deben apuntar al mismo CNAME porque comparten el mismo LB
- si reutilizas automatizacion previa basada en `lb_cname`, recuerda que ese output devuelve solo el CNAME de Arcadia

## 9. Variables importantes

Este caso usa las mismas variables funcionales del caso sin nginx:

- `ARCADIA_DOMAIN`
- `DVWA_DOMAIN`
- `BOUTIQUE_DOMAIN`
- `CRAPI_DOMAIN`
- `MAILHOG_DOMAIN`
- `XC_NAMESPACE`
- `XC_WAF_BLOCKING`
- `XC_API_DISCOVERY`
- `XC_API_PROTECTION`
- `XC_BOT_DEFENSE`

Ademas, el prefijo de recursos AWS y Terraform Cloud se deriva del sufijo `4lbs`.

## 10. Validaciones que ejecuta el workflow

### Validacion del origen en la VM

Antes de crear XC, el job `terraform_vm` valida:

- HTTP en `18080` para Arcadia main
- disponibilidad de puerto en `18081`, `18082`, `18083`
- HTTP en `18084` para DVWA
- HTTP en `18085` para Boutique
- HTTP en `18086` para crAPI
- HTTP en `18087` para Mailhog

### Validacion publica

Despues del `terraform apply` de XC, el workflow prueba:

- `http://ARCADIA_DOMAIN/`
- `http://ARCADIA_DOMAIN/files/`
- `http://ARCADIA_DOMAIN/api/`
- `http://ARCADIA_DOMAIN/app3/`
- `http://DVWA_DOMAIN/`
- `http://BOUTIQUE_DOMAIN/`
- `http://CRAPI_DOMAIN/`
- `http://MAILHOG_DOMAIN/`

## 11. Guias de prueba recomendadas

| Guia | Objetivo |
| --- | --- |
| `readme/README-pruebas-todas-4lbs.md` | Smoke tests rapidos por dominio y LB |
| `readme/README-pruebas-todas-4lbs-completo.md` | Pruebas funcionales y de seguridad separadas por aplicacion |

## 12. Archivos principales del caso

| Archivo | Funcion |
| --- | --- |
| `.github/workflows/sec-re-aws-todas-4lbs.yml` | Orquestacion del deploy |
| `.github/workflows/sec-re-aws-todas-4lbs-destroy.yml` | Orquestacion del destroy |
| `todas-4lbs/infra/security_groups.tf` | Apertura de puertos 18080-18087 |
| `todas-4lbs/vm/userdata.sh` | Instalacion de Docker y despliegue de apps sin nginx |
| `todas-4lbs/vm/outputs.tf` | Export de puertos por aplicacion |
| `todas-4lbs/xc/locals.tf` | Definicion de origin pools y de los cuatro LBs |
| `todas-4lbs/xc/loadbalancer.tf` | Implementacion de los cuatro HTTP Load Balancers |

## 13. Troubleshooting rapido

### Caso: un solo dominio falla y los demas funcionan

Revisar:

- que el LB correspondiente exista en XC
- que el dominio este asociado al LB correcto
- que el origin pool del backend afectado apunte al puerto correcto

### Caso: Mailhog falla pero crAPI responde bien

Revisar:

- que `MAILHOG_DOMAIN` este incluido en el LB de crAPI
- que exista la ruta con `Host: MAILHOG_DOMAIN`
- que el puerto `18087` responda en la VM

### Caso: Arcadia principal responde, pero `/files` o `/api` no

Revisar:

- que los contenedores `backend`, `app2` y `app3` esten arriba
- que los puertos `18081`, `18082` y `18083` esten publicados
- que el LB de Arcadia tenga las rutas hacia los pools correctos