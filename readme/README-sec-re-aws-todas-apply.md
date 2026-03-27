# Seguridad en RE para Arcadia + DVWA en AWS - Deploy

Este workflow despliega una solucion de **WAF sobre el Regional Edge (RE) de F5 Distributed Cloud** para **dos aplicaciones distintas en la misma instancia EC2** de AWS:

- **Arcadia Finance**, accesible por `ARCADIA_DOMAIN`
- **DVWA**, accesible por `DVWA_DOMAIN`

Ambas aplicaciones corren en una sola VM Amazon Linux 2. Dentro de la instancia se levanta un **nginx compartido** que enruta por `Host` hacia los contenedores correctos. En F5 XC se publica **un solo HTTP Load Balancer** que anuncia ambos FQDN y apunta al mismo origin pool.

---

## Resumen de arquitectura y caso de uso

### Que demuestra este laboratorio

| Capacidad | Descripcion |
| --- | --- |
| Dos apps en una sola VM | Arcadia y DVWA comparten la misma EC2 sin necesidad de Kubernetes ni EKS |
| Publicacion por FQDN | Cada aplicacion se publica con su propio dominio: `ARCADIA_DOMAIN` y `DVWA_DOMAIN` |
| WAF en Regional Edge | El trafico entra por el RE global de F5 XC antes de llegar a AWS |
| API Security para Arcadia | Arcadia mantiene API Discovery y API Protection con su swagger OpenAPI |
| WAF para DVWA | DVWA queda expuesta con WAF en el RE para pruebas de seguridad web |
| Infraestructura efimera | Todo se crea con Terraform y se destruye con un workflow dedicado |

### Arquitectura conceptual

```text
Internet
   |
   | HTTP request
   v
+-----------------------------------------------------------+
| F5 Distributed Cloud - Regional Edge                      |
|                                                           |
|  HTTP Load Balancer unico                                 |
|    - ARCADIA_DOMAIN                                       |
|    - DVWA_DOMAIN                                          |
|                                                           |
|  Un solo LB apunta al mismo Origin Pool                   |
+-----------------------------------------------------------+
                           |
                           | origin pool -> EIP del EC2 :8080
                           v
+-----------------------------------------------------------+
| AWS VPC                                                    |
|                                                            |
|  EC2 Amazon Linux 2                                        |
|    - nginx reverse proxy por Host                          |
|    - Arcadia Finance containers                            |
|    - DVWA container                                        |
+-----------------------------------------------------------+
```

---

## Componentes desplegados

```text
todas/infra  -> VPC + Subnet publica + Internet Gateway + Security Group
      |
      v
todas/vm     -> EC2 + Elastic IP + Arcadia + DVWA + nginx reverse proxy
      |
      v
todas/xc     -> XC Namespace + Origin Pool + HTTP LB unico + WAF
```

---

## Objetivo del workflow

1. Aprovisionar la red base en AWS.
2. Desplegar una sola EC2 con Arcadia y DVWA en contenedores separados.
3. Configurar un nginx local que enrute por `Host`:
   - `ARCADIA_DOMAIN` -> Arcadia
   - `DVWA_DOMAIN` -> DVWA
4. Crear en F5 XC un solo HTTP Load Balancer para publicar ambos dominios en el RE.

---

## Workflows relacionados

- Apply: `.github/workflows/sec-re-aws-todas-apply.yml`
- Destroy: `.github/workflows/sec-re-aws-todas-destroy.yml`

---

## Variables y secretos requeridos

### Secrets

| Secreto | Descripcion |
| --- | --- |
| `TF_API_TOKEN` | Token de Terraform Cloud |
| `TF_CLOUD_ORGANIZATION` | Organizacion de Terraform Cloud |
| `AWS_ACCESS_KEY` | Access Key de AWS |
| `AWS_SECRET_KEY` | Secret Key de AWS |
| `XC_API_URL` | URL de API de F5 XC |
| `XC_P12_PASSWORD` | Password del certificado `.p12` |
| `XC_API_P12_FILE` | Certificado `.p12` codificado en base64 |
| `SSH_PRIVATE_KEY` | Llave privada SSH para derivar la publica |

### Variables

| Variable | Ejemplo | Descripcion |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | Region de AWS |
| `PROJECT_PREFIX` | `sec-re-aws-todas` | Prefijo de recursos AWS |
| `XC_NAMESPACE` | `democasos` | Namespace de F5 XC |
| `ARCADIA_DOMAIN` | `arcadia.example.com` | FQDN publico de Arcadia |
| `DVWA_DOMAIN` | `dvwa.example.com` | FQDN publico de DVWA |
| `XC_WAF_BLOCKING` | `true` | Activa WAF en bloqueo o monitoreo |
| `XC_BOT_DEFENSE` | `false` | Activa Bot Defense en Arcadia |

### Workspaces de Terraform Cloud usados por este caso

| Workspace | Uso |
| --- | --- |
| `sec-re-aws-todas-infra` | Infraestructura AWS |
| `sec-re-aws-todas-vm` | VM compartida con Arcadia y DVWA |
| `sec-re-aws-todas-xc` | Objetos de F5 XC |

---

## Jobs principales

### `terraform_infra`

- Directorio: `todas/infra`
- Crea VPC, subnet publica, Internet Gateway y security group.

### `terraform_vm`

- Directorio: `todas/vm`
- Crea una EC2 con Elastic IP.
- Instala Docker.
- Levanta Arcadia y DVWA en la misma red Docker.
- Publica ambos servicios a traves de un nginx local en el puerto `8080`.

### `terraform_xc`

- Directorio: `todas/xc`
- Crea un origin pool comun hacia la misma VM.
- Publica **Arcadia** y **DVWA** en un solo HTTP Load Balancer con ambos dominios.
- Mantiene API Discovery y API Protection para Arcadia.

---

## Enrutamiento dentro de la VM

El archivo `todas/vm/userdata.sh` genera un `default.conf` para nginx con routing por `server_name`:

- `server_name ARCADIA_DOMAIN` -> Arcadia
- `server_name DVWA_DOMAIN` -> DVWA

Esto evita problemas de path-based routing como `/arcadia` o `/dvwa`, y deja cada aplicacion en su raiz natural.

---

## Acceso a las aplicaciones

### Arcadia

- URL esperada: `http://ARCADIA_DOMAIN/trading/login.php`
- Mantiene el caso de uso de API Security.

### DVWA

- URL esperada: `http://DVWA_DOMAIN/setup.php`
- Permite pruebas de WAF y modulos vulnerables clasicos.

---

## Ejecucion manual

### Deploy

1. Ir a **Actions**.
2. Ejecutar `Seguridad en RE para Arcadia + DVWA en AWS - Deploy`.
3. Esperar a que terminen `terraform_infra`, `terraform_vm` y `terraform_xc`.

### Destroy

1. Ir a **Actions**.
2. Ejecutar `Seguridad en RE para Arcadia + DVWA en AWS - Destroy`.
3. El orden de destruccion es:
   - XC
   - VM
   - Infra

---

## Troubleshooting rapido

- **La VM responde pero una aplicacion no carga:**
  Revisar `cloud-init` y el estado de contenedores en la EC2.

  ```bash
  ssh -i <private_key> ec2-user@<elastic_ip> "sudo cat /var/log/cloud-init-output.log"
  ssh -i <private_key> ec2-user@<elastic_ip> "sudo docker ps"
  ```

- **Arcadia carga pero DVWA no responde:**
  Verificar que el request llegue con el host correcto `DVWA_DOMAIN`. El nginx interno enruta por `server_name`.

- **DVWA responde pero Arcadia falla en endpoints API:**
  Verificar que el swagger de Arcadia se haya subido correctamente al object store de F5 XC.

- **Re-ejecucion del apply con namespace existente:**
  El workflow acepta `409` al crear el namespace.

- **Advertencias en `todas/xc/waf.tf`:**
  El provider marca dos argumentos como deprecados, pero el modulo valida correctamente y no bloquea el despliegue.

---

## Archivos principales del caso

- `todas/infra`
- `todas/vm`
- `todas/xc`
- `.github/workflows/sec-re-aws-todas-apply.yml`
- `.github/workflows/sec-re-aws-todas-destroy.yml`