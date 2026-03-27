# Seguridad en RE para Arcadia + DVWA + Boutique + crAPI en AWS - Deploy sin nginx

Este workflow despliega una solucion de **seguridad en el Regional Edge (RE) de F5 Distributed Cloud** para **cuatro aplicaciones principales alojadas en una sola instancia EC2 de AWS**, pero **sin nginx en la VM**:

- **Arcadia Finance**, publicada por `ARCADIA_DOMAIN`
- **DVWA**, publicada por `DVWA_DOMAIN`
- **Online Boutique**, publicada por `BOUTIQUE_DOMAIN`
- **crAPI**, publicada por `CRAPI_DOMAIN`
- **Mailhog**, publicada por `MAILHOG_DOMAIN` como interfaz web de apoyo para crAPI

La diferencia clave respecto al caso 8 es que el enrutamiento ya no ocurre en la instancia EC2. En su lugar:

- cada servicio se expone directamente en un puerto distinto del host
- F5 XC crea **un solo HTTP Load Balancer**
- el **routing por Host y path** se resuelve en XC mediante varias rutas hacia varios origin pools

## 1. Resumen ejecutivo

### Que despliega

El workflow crea tres capas desacopladas:

| Capa | Directorio | Funcion |
| --- | --- | --- |
| Infra AWS | `todas_sin_nginx/infra` | VPC, subnet publica, internet gateway, rutas, security group y recursos base |
| VM compartida | `todas_sin_nginx/vm` | EC2 + EIP + Docker + Arcadia + DVWA + Boutique + crAPI + Mailhog |
| Seguridad XC | `todas_sin_nginx/xc` | origin pools multiples, un solo HTTP Load Balancer, WAF, API Security y Bot Defense |

### Que NO usa este caso

- No usa EKS
- No usa Customer Edge
- No usa AppConnect
- No usa nginx en el host
- No usa un load balancer distinto por aplicacion

### Cuadro tecnico del caso

Este caso es util cuando quieres demostrar una variante mas directa del origen compartido:

- un solo LB publico en XC
- una sola VM en AWS
- varios backends publicados por puerto
- reglas de routing centralizadas en XC en vez de hacerlo con un proxy local

## 2. Arquitectura final

### Flujo de trafico

```text
Cliente / Internet
        |
        | HTTP request con Host: arcadia|dvwa|boutique|crapi|mailhog
        v
+---------------------------------------------------------------+
| F5 Distributed Cloud - Regional Edge                          |
|                                                               |
|  HTTP Load Balancer unico                                     |
|    - ARCADIA_DOMAIN                                           |
|    - DVWA_DOMAIN                                              |
|    - BOUTIQUE_DOMAIN                                          |
|    - CRAPI_DOMAIN                                             |
|    - MAILHOG_DOMAIN                                           |
|                                                               |
|  Rutas en XC                                                  |
|    - Host arcadia + /files -> pool arcadia-files             |
|    - Host arcadia + /api   -> pool arcadia-api               |
|    - Host arcadia + /app3  -> pool arcadia-app3              |
|    - Host arcadia + /      -> pool arcadia-main              |
|    - Host dvwa            -> pool dvwa                       |
|    - Host boutique        -> pool boutique                   |
|    - Host crapi           -> pool crapi                      |
|    - Host mailhog         -> pool mailhog                    |
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

## 3. Diferencia frente al caso 8

| Tema | Caso 8 | Caso 9 |
| --- | --- | --- |
| Proxy local | nginx en el host | no usa nginx |
| Puerto de origen visto por XC | uno solo, `80` | varios, `18080-18087` |
| Routing por Host/path | en nginx | en XC |
| Origin pools en XC | uno | multiples |
| Security group | mas cerrado para apps | mas abierto hacia puertos de app |

La consecuencia mas importante es esta:

- el caso 8 reduce superficie expuesta usando nginx como punto de agregacion
- el caso 9 simplifica la VM y mueve la logica de routing al LB de XC

## 4. Aplicaciones publicadas

| Aplicacion | Dominio | URL base esperada | Puerto origen |
| --- | --- | --- | --- |
| Arcadia Finance | `ARCADIA_DOMAIN` | `http://ARCADIA_DOMAIN/` | `18080` |
| Arcadia files | `ARCADIA_DOMAIN/files` | `http://ARCADIA_DOMAIN/files/` | `18081` |
| Arcadia api | `ARCADIA_DOMAIN/api` | `http://ARCADIA_DOMAIN/api/` | `18082` |
| Arcadia app3 | `ARCADIA_DOMAIN/app3` | `http://ARCADIA_DOMAIN/app3/` | `18083` |
| DVWA | `DVWA_DOMAIN` | `http://DVWA_DOMAIN/` | `18084` |
| Online Boutique | `BOUTIQUE_DOMAIN` | `http://BOUTIQUE_DOMAIN/` | `18085` |
| crAPI | `CRAPI_DOMAIN` | `http://CRAPI_DOMAIN/` | `18086` |
| Mailhog | `MAILHOG_DOMAIN` | `http://MAILHOG_DOMAIN/` | `18087` |

## 5. Workflows involucrados

| Workflow | Archivo | Objetivo |
| --- | --- | --- |
| Deploy | `.github/workflows/sec-re-aws-todas-sin-ngix-apply.yml` | Crear AWS + VM sin nginx + F5 XC + validaciones |
| Destroy | `.github/workflows/sec-re-aws-todas-sin-ngix-destroy.yml` | Eliminar XC, luego VM, luego infra y limpiar specs |

### Orden del deploy

El workflow ejecuta tres jobs en cadena:

1. `terraform_infra`
2. `terraform_vm`
3. `terraform_xc`

### Orden del destroy

El workflow de destroy ejecuta el orden inverso:

1. `terraform_xc`
2. `terraform_vm`
3. `terraform_infra`

## 6. Terraform Cloud

Deben existir estos tres workspaces y estar en modo de ejecucion **Local**:

- `sec-re-aws-todas-sin-nginx-infra`
- `sec-re-aws-todas-sin-nginx-vm`
- `sec-re-aws-todas-sin-nginx-xc`

## 7. Variables importantes

Ademas de las variables ya conocidas del caso 8, este caso usa el mismo conjunto funcional:

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

## 8. Validaciones que ejecuta el workflow

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

## 9. Consideraciones de seguridad

Este caso cumple el objetivo funcional de eliminar nginx, pero tiene un tradeoff claro:

- la instancia EC2 ya no expone un solo puerto de origen
- el security group debe permitir acceso a varios puertos de app
- por tanto, la superficie expuesta es mayor que en el caso 8

Si tu prioridad es **simplicidad operativa del host** y centralizar routing en XC, este caso es valido.
Si tu prioridad es **minimizar puertos expuestos en AWS**, el caso 8 sigue siendo mas fuerte.

## 10. Archivos principales del caso

| Archivo | Funcion |
| --- | --- |
| `.github/workflows/sec-re-aws-todas-sin-ngix-apply.yml` | Orquestacion del deploy |
| `.github/workflows/sec-re-aws-todas-sin-ngix-destroy.yml` | Orquestacion del destroy |
| `todas_sin_nginx/infra/security_groups.tf` | Apertura de puertos 18080-18087 |
| `todas_sin_nginx/vm/userdata.sh` | Instalacion de Docker y despliegue de apps sin nginx |
| `todas_sin_nginx/vm/outputs.tf` | Export de puertos por aplicacion |
| `todas_sin_nginx/xc/loadbalancer.tf` | Origin pools multiples y rutas del LB |
| `todas_sin_nginx/xc/locals.tf` | Wiring entre outputs de VM y pools de XC |

## 11. Troubleshooting rapido

### Caso: la VM arranca pero Arcadia responde y `/files` o `/api` no

Revisar:

- que los contenedores `backend`, `app2` y `app3` esten arriba
- que los puertos `18081`, `18082` y `18083` esten publicados
- que las rutas de XC apunten al pool correcto

### Caso: XC devuelve `503` en un dominio concreto

Revisar:

- que el origin pool correcto exista en XC
- que el puerto asociado en la VM este accesible
- que la ruta del LB tenga el `Host` correcto

### Caso: Terraform validate muestra warnings en WAF

En `todas_sin_nginx/xc/waf.tf` hay argumentos deprecados heredados del provider `volterra`:

- `default_bot_setting`
- `use_loadbalancer_setting`

Hoy no bloquean el `validate`, pero conviene revisarlos cuando se actualice el provider.