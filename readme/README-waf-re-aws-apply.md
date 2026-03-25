# WAF en RE para VM en AWS - Deploy

Este workflow despliega una solución de **Web Application Firewall (WAF) con F5 Distributed Cloud sobre el Regional Edge (RE)**, protegiendo la aplicación **Arcadia Finance** que corre en una instancia EC2 dentro de un VPC en AWS. El tráfico de internet pasa por el RE global de F5 XC antes de ser reenviado a la aplicación.

---

## Resumen de arquitectura y caso de uso

### ¿Para qué sirve este laboratorio?

| Capacidad                       | Descripción                                                                                            |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ |
| WAF en Regional Edge            | F5 XC inspecciona el tráfico en el RE global, sin necesidad de desplegar un Customer Edge en AWS.      |
| VIP pública en RE               | El HTTP Load Balancer usa `advertise_on_public_default_vip = true` para exponer la app via RE.         |
| Aplicación en EC2               | Arcadia Finance corre en una instancia EC2 Amazon Linux 2 con Docker Compose (vía `userdata.sh`).      |
| Modo blocking configurable      | La WAF policy puede operar en modo bloqueo o detección, controlado por la variable `XC_WAF_BLOCKING`.  |
| Infraestructura efímera         | Todo se provisiona desde cero con Terraform y se destruye con el workflow de destroy.                  |
| Estado remoto compartido        | Los tres workspaces de TFC comparten estado remoto para pasar outputs (IP del EC2, puerto) entre módulos. |

### Arquitectura conceptual

```
Internet
   │
   │  HTTP request
   ▼
┌─────────────────────────────────────────────────────────┐
│          F5 Distributed Cloud — Regional Edge (RE)       │
│                                                          │
│  • WAF inspection (block/detect mode)                   │
│  • HTTP Load Balancer                                   │
│  • advertise_on_public_default_vip = true               │
└─────────────────────────────────────────────────────────┘
                           │
                           │  Forward (origin pool → public IP del EC2)
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      AWS VPC                             │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  EC2 Instance (Amazon Linux 2)                    │  │
│  │                                                    │  │
│  │  Elastic IP (public)                              │  │
│  │      │                                            │  │
│  │      ▼                                            │  │
│  │  Arcadia Finance (Docker Compose — userdata.sh)   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Casos de Uso para Laboratorio

1. Demostración de WAF en RE sin necesidad de instalar un Customer Edge en la nube del cliente.
2. Laboratorio de protección de aplicaciones en EC2 con F5 XC WAF.
3. Validación de políticas WAF de F5 XC (bloqueo de SQLi, XSS, ataques OWASP Top 10).
4. Entorno de pruebas efímero para workshops y capacitaciones de F5 Distributed Cloud.
5. Comparación de modelos de publicación: RE con IP pública (este caso) vs. RE + CE AppConnect sin IP pública (caso AppConnect).

### Casos de Uso Reales

1. **Protección de aplicaciones web expuestas a internet con IP pública en AWS.** El patrón más simple para añadir WAF a una aplicación en EC2 con Elastic IP: el RE de F5 XC actúa como proxy inverso global, inspecciona el tráfico y reenvía solo peticiones limpias al origen. No requiere cambios en la infraestructura de la aplicación.

2. **Migración de WAF on-prem o WAF de nube a F5 Distributed Cloud.** Organizaciones con aplicaciones en EC2 que usan WAF de AWS (WAF nativo), ModSecurity u otra solución, y quieren centralizar la gestión de políticas WAF en F5 XC sin mover la aplicación ni modificar la red.

3. **WAF en RE como primera línea de defensa antes del ALB o API Gateway.** Empresas que tienen un Application Load Balancer o API Gateway en AWS y quieren añadir una capa WAF global antes del balanceador. El RE de F5 XC absorbe el tráfico malicioso antes de que llegue a la infraestructura de AWS.

4. **Protección de aplicaciones legacy sin soporte para certificados TLS modernos.** Aplicaciones en EC2 que no soportan TLS 1.3 o certificados modernos. El RE de F5 XC termina TLS hacia el cliente y reenvía al origen en HTTP plano o TLS legacy — desacoplando el perfil TLS de la app del perfil expuesto al cliente.

5. **Demo de WAF para clientes y prospects de F5.** Entorno efímero que se despliega en minutos con Terraform, demuestra bloqueo de ataques OWASP Top 10 en tiempo real, y se destruye completamente al finalizar — sin costes residuales ni configuración manual.

### Componentes desplegados

```
aws/waf-re-aws/infra  ──►  VPC + Subnet pública + Internet Gateway + Security Groups
        │
        ▼
aws/waf-re-aws/vm     ──►  EC2 (Arcadia Finance) + Elastic IP + Key Pair SSH
        │
        ▼
aws/waf-re-aws/xc     ──►  XC Namespace + Origin Pool + HTTP LB + WAF Policy (RE)
```

---

## Objetivo del workflow

1. Crear (o verificar) los tres workspaces de Terraform Cloud con modo de ejecución `local` y Remote State Sharing habilitado entre ellos.
2. Aprovisionar la infraestructura de red en AWS: VPC, subred pública, Internet Gateway, Route Table y Security Groups.
3. Desplegar la instancia EC2 con la aplicación **Arcadia Finance** (Docker Compose via `userdata.sh`) y su Elastic IP.
4. Configurar en F5 Distributed Cloud el namespace, la WAF policy, el Origin Pool y el HTTP Load Balancer publicado en el **Regional Edge**.

---

## Triggers

```yaml
on:
  workflow_dispatch:
```

- **`workflow_dispatch`:** ejecución manual desde la pestaña **Actions** de GitHub.

---

## Secretos requeridos

Configurar en **Settings → Secrets and variables → Secrets**:

### Terraform Cloud

| Secreto                 | Descripción                                  |
| ----------------------- | -------------------------------------------- |
| `TF_API_TOKEN`          | Token de API de Terraform Cloud              |
| `TF_CLOUD_ORGANIZATION` | Nombre de la organización en Terraform Cloud |

### AWS

| Secreto            | Descripción                              |
| ------------------ | ---------------------------------------- |
| `AWS_ACCESS_KEY`   | Access Key ID de la cuenta AWS           |
| `AWS_SECRET_KEY`   | Secret Access Key de la cuenta AWS       |

### F5 Distributed Cloud

| Secreto           | Descripción                                                             |
| ----------------- | ----------------------------------------------------------------------- |
| `XC_API_URL`      | URL de la API de F5 XC (`https://<tenant>.console.ves.volterra.io/api`) |
| `XC_P12_PASSWORD` | Contraseña del certificado `.p12` de F5 XC                              |
| `XC_API_P12_FILE` | Certificado API de F5 XC en formato `.p12` codificado en **base64**     |

### SSH

| Secreto           | Descripción                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| `SSH_PRIVATE_KEY` | Llave privada SSH (la pública se deriva en runtime con `ssh-keygen -y`). Usada en el EC2 Key Pair. |

---

## Variables requeridas

Configurar en **Settings → Secrets and variables → Variables**:

### Terraform Cloud — Workspaces

| Variable                        | Ejemplo              | Descripción                                        |
| ------------------------------- | -------------------- | -------------------------------------------------- |
| `TF_CLOUD_WORKSPACE_AWS_INFRA`  | `waf-re-aws-infra`   | Nombre del workspace de TFC para AWS Infra         |
| `TF_CLOUD_WORKSPACE_AWS_VM`     | `waf-re-aws-vm`      | Nombre del workspace de TFC para la VM (EC2)       |
| `TF_CLOUD_WORKSPACE_AWS_XC`     | `waf-re-aws-xc`      | Nombre del workspace de TFC para F5 XC             |

### Infraestructura

| Variable         | Ejemplo      | Descripción                                         |
| ---------------- | ------------ | --------------------------------------------------- |
| `AWS_REGION`     | `us-east-1`  | Región de AWS donde se despliegan los recursos      |
| `PROJECT_PREFIX` | `waf-re-aws` | Prefijo para nombrar todos los recursos creados     |

### Aplicación

| Variable           | Ejemplo                        | Descripción                                          |
| ------------------ | ------------------------------ | ---------------------------------------------------- |
| `XC_NAMESPACE`     | `arcadia-prod`                 | Namespace de F5 XC donde se crea el LB y WAF         |
| `ARCADIA_DOMAIN`   | `arcadia-aws.example.com`      | FQDN de la aplicación en el HTTP LB de F5 XC         |
| `XC_WAF_BLOCKING`  | `true`                         | `true` = modo bloqueo; `false` = modo detección      |

---

## Jobs principales

### `terraform_infra` — AWS Infra

- **Módulo:** `aws/waf-re-aws/infra`
- **Workspace TFC:** `TF_CLOUD_WORKSPACE_AWS_INFRA`
- **Qué crea:**
  - VPC con DNS habilitado (`enable_dns_support`, `enable_dns_hostnames`).
  - Internet Gateway y Route Table pública.
  - Subred pública con `map_public_ip_on_launch = true`.
  - Security Groups con reglas de acceso HTTP, HTTPS y SSH.
- **Outputs:** IDs de VPC, subred y SG (consumidos por el job `terraform_vm` vía estado remoto).

### `terraform_vm` — AWS VM (Arcadia)

- **Módulo:** `aws/waf-re-aws/vm`
- **Workspace TFC:** `TF_CLOUD_WORKSPACE_AWS_VM`
- **Depende de:** `terraform_infra`
- **Qué crea:**
  - Key Pair SSH (public key derivada en runtime desde `SSH_PRIVATE_KEY` con `ssh-keygen -y`).
  - Instancia EC2 Amazon Linux 2 (`t3.micro` o el tipo configurado) con `userdata.sh` para instalar Docker Compose y levantar Arcadia Finance.
  - Elastic IP asignada a la instancia.
  - Volumen root de 20 GB con monitoring habilitado.
- **Nota:** usa estado remoto de `aws/infra` para obtener IDs de subred y SG.
- **Outputs:** IP pública del EC2 y puerto de la app (consumidos por `terraform_xc`).

### `terraform_xc` — F5XC WAF

- **Módulo:** `aws/waf-re-aws/xc`
- **Workspace TFC:** `TF_CLOUD_WORKSPACE_AWS_XC`
- **Depende de:** `terraform_vm`
- **Qué crea / configura:**
  - Namespace de F5 XC.
  - WAF Policy (`volterra_app_firewall`) con modo configurable (blocking/monitoring).
  - Origin Pool apuntando a la IP pública del EC2.
  - HTTP Load Balancer publicado en el Regional Edge (`advertise_on_public_default_vip = true`).
- **Parámetros relevantes:**

  | Variable Terraform              | Origen                             | Propósito                                        |
  | ------------------------------- | ---------------------------------- | ------------------------------------------------ |
  | `TF_VAR_tf_cloud_workspace_infra` | `TF_CLOUD_WORKSPACE_AWS_INFRA`  | Estado remoto de infra (VPC/subnet IDs)          |
  | `TF_VAR_tf_cloud_workspace_vm`  | `TF_CLOUD_WORKSPACE_AWS_VM`        | Estado remoto de VM (IP EC2, puerto app)         |
  | `TF_VAR_xc_waf_blocking`        | `XC_WAF_BLOCKING` (var)            | Modo de WAF: `true` = bloqueo, `false` = detección |

---

## Arquitectura desplegada por el workflow

```mermaid
flowchart LR
  INET[Internet]

  subgraph XC_PLATFORM[F5 Distributed Cloud — Regional Edge]
    XC_LB[HTTP Load Balancer\nadvertise_on_public_default_vip]
    XC_WAF[WAF Policy\nblocking / monitoring]
    XC_NS[XC Namespace]
    XC_NS --> XC_LB
    XC_LB --> XC_WAF
  end

  subgraph AWS_VPC[AWS VPC]
    SG[Security Group\nHTTP + SSH]

    subgraph EC2[EC2 Instance — Amazon Linux 2]
      EIP[Elastic IP]
      ARCADIA[Arcadia Finance\nDocker Compose]
      EIP --> ARCADIA
    end

    SG --> EC2
  end

  INET -->|HTTP| XC_LB
  XC_LB -->|origin pool\npublic IP EC2| EIP
```

---

## Troubleshooting rápido

- **Error `exit code 58` o falla al decodificar el P12:**
  Confirmar que `XC_API_P12_FILE` esté codificado en base64 correctamente:

  ```bash
  base64 -i api.p12 | pbcopy   # macOS
  base64 api.p12 | xclip       # Linux
  ```

- **EC2 no responde en el origen pool:**
  La aplicación Arcadia corre vía `userdata.sh` al lanzar la instancia. Puede tardar 2-3 minutos en estar disponible. Verificar el estado del `userdata` con:

  ```bash
  ssh -i <private_key> ec2-user@<EIP> "sudo cat /var/log/cloud-init-output.log"
  ```

- **Workspace TFC no encontrado durante `terraform init`:**
  Verificar que las variables `TF_CLOUD_WORKSPACE_AWS_INFRA`, `TF_CLOUD_WORKSPACE_AWS_VM` y `TF_CLOUD_WORKSPACE_AWS_XC` estén configuradas en el repositorio y que el token `TF_API_TOKEN` tenga permisos sobre la organización correcta.

- **Plan fallido en `terraform_xc` por estado remoto vacío:**
  El job `terraform_xc` depende de los outputs de `terraform_infra` y `terraform_vm`. Si alguno de los dos workspaces previos no tiene estado, `terraform_xc` fallará. Re-ejecutar el workflow completo.

- **Error 409 al crear el namespace en re-ejecuciones:**
  El step _"Create XC Namespace if not exists"_ usa `curl` para pre-crear el namespace antes del `terraform apply`. Si el namespace ya existe, el API responde 409 — este código se acepta como éxito y el workflow continúa sin error. Terraform ya no gestiona el recurso `volterra_namespace`.

- **El step `Remove namespace from TF state` muestra "Invalid target address":**
  En la primera ejecución limpia, `volterra_namespace.this` no existe en el estado de TFC y `terraform state rm` finaliza con código 1. El `|| true` absorbe el error — comportamiento esperado, puede ignorarse.

- **Variable `ARCADIA_DOMAIN` no configurada:**
  Debe existir como variable de repositorio en GitHub → **Settings → Secrets and variables → Variables**. Ejemplo: `arcadia-aws.example.com`. Si no está definida, el step de Terraform fallará con variable vacía.

- **WAF en modo detección (no bloquea ataques):**
  Verificar que `XC_WAF_BLOCKING` esté en `true`. Si está en `false`, la WAF policy registra pero no bloquea.

---

## Ejecución manual

**Archivo de workflow:** `.github/workflows/waf-re-aws-apply.yml`

1. Ir a **Actions** en GitHub.
2. Seleccionar el workflow: **WAF en RE para VM en AWS - Deploy**.
3. Hacer clic en **Run workflow**.
4. Confirmar la ejecución. No hay inputs adicionales.

### Criterios de éxito

- Los tres jobs (`terraform_infra`, `terraform_vm`, `terraform_xc`) terminan en estado `success`.
- El namespace indicado en `XC_NAMESPACE` existe en la consola de F5 XC.
- El HTTP Load Balancer aparece publicado con una VIP pública en el Regional Edge.
- La aplicación Arcadia Finance es accesible desde internet a través del dominio configurado en `ARCADIA_DOMAIN`.

---

## Uso de la aplicación Arcadia Finance

### Acceso inicial

Navegar a `http://<ARCADIA_DOMAIN>/` en el navegador. La aplicación Arcadia Finance estará disponible directamente — no requiere inicialización manual.

### Credenciales por defecto

| Usuario         | Contraseña  |
| --------------- | ----------- |
| `admin`         | `iloveblue` |
| `matt`          | `ilovef5`   |
| `jim`           | `ilovef5`   |
| `anna`          | `ilovef5`   |

### Módulos y endpoints disponibles

Arcadia Finance expone una API REST y una interfaz web con los siguientes endpoints:

| Endpoint                        | Descripción                                      |
| ------------------------------- | ------------------------------------------------ |
| `/`                             | Página principal (login)                         |
| `/trading/`                     | Panel de trading de acciones                     |
| `/api/rest/execute_transaction/`| API para transacciones (JSON POST)               |
| `/api/rest/get_balance/`        | API para consultar saldo                         |
| `/api/rest/get_stock_value/`    | API para consultar precio de acciones            |
| `/api/rest/login/`              | API de autenticación                             |

### Verificación del WAF

Con `XC_WAF_BLOCKING=true`, los ataques son bloqueados antes de llegar a la aplicación. Ejemplos de prueba:

```bash
# SQLi en parámetro de URL — debe ser bloqueado
curl -i "http://<ARCADIA_DOMAIN>/api/rest/get_stock_value/?stock=' OR '1'='1"

# XSS reflejado — debe ser bloqueado
curl -i "http://<ARCADIA_DOMAIN>/?q=<script>alert(1)</script>"

# Command injection — debe ser bloqueado
curl -i "http://<ARCADIA_DOMAIN>/api/rest/get_balance/?user=admin;id"

# Petición legítima — debe pasar
curl -i "http://<ARCADIA_DOMAIN>/api/rest/get_stock_value/?stock=AAPL"
```

Los eventos de bloqueo quedan registrados en F5 XC → **Security → Security Events** del namespace configurado en `XC_NAMESPACE`.

---

## Destroy del laboratorio

El archivo [`.github/workflows/waf-re-aws-destroy.yml`](../.github/workflows/waf-re-aws-destroy.yml) destruye **todos** los recursos creados por el apply en orden inverso para evitar dependencias huérfanas en F5 XC y AWS.

**Trigger:** `workflow_dispatch` — ejecución manual desde GitHub Actions.

> **Nota:** el namespace de F5 XC (`XC_NAMESPACE`) también es eliminado via `curl DELETE` al finalizar el destroy de `terraform_xc`, antes de proceder con los recursos de AWS.

### Orden de destrucción

```
terraform_xc     (1° — elimina LB, WAF policy, Origin Pool, namespace XC)
      │
      ▼
terraform_vm     (2° — elimina EC2, Elastic IP, Key Pair)
      │
      ▼
terraform_infra  (3° — elimina VPC, subredes, SGs, Internet Gateway)
```
