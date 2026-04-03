# Deploy AWS Module 1

Este documento describe el workflow de GitHub Actions:

- `.github/workflows/deploy-aws-module-1.yml`

Su objetivo es desplegar en AWS un **App Stack Site de F5 Distributed Cloud (XC)** con **managed Kubernetes (mK8s)** y luego publicar el laboratorio **Buytime Module 1** mediante dos HTTP Load Balancers internos: **kiosk** y **recommendations**.

---

## Resumen de arquitectura y caso de uso

### ¿Para qué sirve este laboratorio?

Este caso automatiza un entorno de aplicación sobre **F5 XC App Stack en AWS**. El workflow crea primero los prerequisitos de infraestructura y del site, y después despliega la aplicación sobre el mK8s del propio App Stack.

Las capacidades principales del caso son:

| Capacidad | Descripción |
| --------- | ----------- |
| **App Stack Site en AWS** | Crea un sitio de tipo App Stack sobre AWS VPC Site, con cluster mK8s gestionado por F5 XC. |
| **Namespace XC opcionalmente autogestionado** | Si el namespace indicado no existe, el workflow lo crea antes de desplegar el resto de recursos. |
| **Kubeconfig temporal y revocable** | Genera una credencial temporal para acceder al mK8s del site, la usa durante el deploy y la revoca al final. |
| **Aplicación multi-componente** | Despliega `mysql`, `wordpress` y `kiosk` dentro del mK8s usando manifiestos Kubernetes aplicados por Terraform. |
| **Publicación interna de servicios** | Expone dos dominios internos: `kiosk.<namespace>.buytime.internal` desde mK8s y `recommendations.<namespace>.buytime.internal` hacia un origin HTTPS externo. |
| **Kiosk Windows en AWS** | Crea una VM Windows pública para consumir la aplicación desde una sesión RDP, útil en demos y laboratorios. |

### Arquitectura conceptual

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                    F5 Distributed Cloud (XC)                              │
│                                                                            │
│   Namespace <xc_namespace>                                                 │
│   ├─ AWS App Stack Site                                                    │
│   ├─ Managed Kubernetes (mK8s)                                             │
│   ├─ HTTP LB: kiosk.<namespace>.buytime.internal                           │
│   └─ HTTP LB: recommendations.<namespace>.buytime.internal                 │
└────────────────────────────────────────────────────────────────────────────┘
                    │
                    │ advertised on site network
                    ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ AWS                                                                        │
│                                                                            │
│ VPC <project-prefix>-<namespace>-vpc                                       │
│ ├─ Subnet A                                                                │
│ │  ├─ XC App Stack node / site resources                                   │
│ │  └─ Windows Kiosk VM (RDP público)                                       │
│ └─ Managed workloads in mK8s                                               │
│    ├─ mysql                                                                │
│    ├─ wordpress                                                            │
│    └─ kiosk reverse proxy                                                  │
└────────────────────────────────────────────────────────────────────────────┘

kiosk.buytime.internal             -> origin pool hacia servicio `kiosk-service` en mK8s
recommendations.buytime.internal   -> origin pool hacia `recommendations.buytime.sr.f5-cloud-demo.com:443`
```

### Qué despliega exactamente

En la fase de **prerequisites**:

1. Valida variables obligatorias del repositorio y el CIDR del VPC.
2. Calcula el prefijo de workspaces de Terraform Cloud.
3. Decodifica y valida el certificado P12 usado por el provider de XC.
4. Detecta si el namespace de XC ya existe.
5. Crea o reutiliza el namespace.
6. Crea el VPC y la subred de AWS.
7. Registra las cloud credentials de AWS en XC.
8. Crea el cluster mK8s y el AWS App Stack Site.
9. Etiqueta el site y fuerza la accion `apply` en XC.
10. Crea una VM Windows de tipo kiosk con IP publica y acceso RDP.

En la fase de **module_1**:

1. Espera a que el App Stack Site quede en estado operativo en XC.
2. Genera un kubeconfig temporal mediante una service credential de XC.
3. Espera a que el API server del mK8s responda.
4. Aplica los manifiestos Kubernetes del laboratorio Buytime Module 1.
5. Crea un origin pool y un HTTP LB interno para `kiosk.<namespace>.buytime.internal`.
6. Crea un origin pool y un HTTP LB interno para `recommendations.<namespace>.buytime.internal`.
7. Revoca la credencial temporal usada para construir el kubeconfig.

---

## Objetivo del workflow

El workflow resuelve en una sola ejecución el bootstrap completo del laboratorio:

1. Infraestructura base en AWS.
2. Registro y preparación del site App Stack en XC.
3. Acceso temporal y controlado al mK8s del site.
4. Despliegue de la aplicación Buytime Module 1.
5. Publicación interna de los endpoints necesarios para la demo.

---

## Trigger

- `workflow_dispatch`
  - Ejecución manual desde GitHub Actions.
  - No define inputs manuales: toma la configuración desde variables y secretos del repositorio.

---

## Variables del repositorio

### Obligatorias

- `AWS_REGION`
- `PROJECT_PREFIX`
- `VPC_CIDR`
- `XC_NAMESPACE`

### Opcional

- `XC_SERVICE_CREDENTIAL_ROLE`

Si `XC_SERVICE_CREDENTIAL_ROLE` no está definido, el workflow intenta crear la credencial temporal usando esta secuencia de roles hasta encontrar uno válido:

- `ves-io-admin-role`
- `Admin`
- `admin`
- `Standard`
- `standard`
- `ves-io-admin`

---

## Secretos requeridos

### Terraform Cloud

- `TF_CLOUD_ORGANIZATION`
- `TF_API_TOKEN`

### F5 Distributed Cloud

- `XC_API_URL`
- `XC_API_P12_FILE`
- `XC_P12_PASSWORD`

### AWS

- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`

---

## Workspaces de Terraform Cloud

El workflow construye dinámicamente el prefijo del workspace a partir de:

- `PROJECT_PREFIX`
- `XC_NAMESPACE`

Con ese prefijo crea o reutiliza estos workspaces remotos:

- `<workspace_prefix>-prerequisites`
- `<workspace_prefix>-module-1`

Ejemplo:

```text
PROJECT_PREFIX=buytime
XC_NAMESPACE=demo

workspace_prefix=buytime-demo
buytime-demo-prerequisites
buytime-demo-module-1
```

---

## Jobs principales

### `prerequisites`

Aplica la base del entorno y exporta outputs para el siguiente job:

- `app_stack_name`
- `mk8s_cluster_name`
- `xc_namespace`
- `workspace_prefix`

Además deja disponibles en el estado remoto outputs útiles como:

- IP privada del App Stack.
- VPC ID y subnet ID.
- IP pública del kiosk Windows.
- Usuario `administrator`.
- Password descifrado de Windows.

### `module_1`

Consume los outputs del job anterior y completa el despliegue de la aplicación:

- espera readiness del site,
- genera kubeconfig temporal,
- verifica el API del mK8s,
- ejecuta Terraform sobre `aws-mk8s-vk8s/module-1`,
- elimina la credencial temporal incluso si el job falla.

---

## Recursos principales creados

### En AWS

- 1 VPC.
- 1 subred.
- 1 instancia Windows pública para kiosk.
- 1 security group con RDP abierto en `3389/tcp`.
- 1 key pair para recuperar la password de Windows.

### En F5 XC

- 1 namespace de aplicación si no existía.
- 1 cloud credential de AWS.
- 1 mK8s cluster.
- 1 AWS App Stack Site.
- 2 origin pools.
- 2 HTTP Load Balancers internos.
- 1 service credential temporal para generar kubeconfig.

### En Kubernetes del App Stack

- Namespace de aplicación.
- Deployment y Service de MySQL.
- Deployment y Service de WordPress.
- Deployment y Service de kiosk.

---

## Dominios publicados

El módulo 1 publica estos dominios internos:

| Dominio | Backend | Puerto | Tipo |
| ------- | ------- | ------ | ---- |
| `kiosk.<namespace>.buytime.internal` | `kiosk-service.<namespace>` en mK8s | `8080` | Interno sobre el App Stack Site |
| `recommendations.<namespace>.buytime.internal` | `recommendations.buytime.sr.f5-cloud-demo.com` | `443` | Interno sobre el App Stack Site |

El workflow desactiva explícitamente WAF, API Discovery, API Definition y rate limiting en estos dos HTTP Load Balancers, por lo que este caso está orientado a **conectividad y publicación de aplicación**, no a demostraciones de seguridad en RE.

---

## Validaciones incorporadas

Antes de desplegar el módulo, el workflow valida:

1. Que el `VPC_CIDR` sea correcto.
2. Que el certificado P12 de XC no esté expirado.
3. Que el App Stack Site llegue a un estado aceptable en XC:
   - `ONLINE`
   - `ORCHESTRATION_COMPLETE`
   - `VALIDATION_SUCCESS`
4. Que el API server del mK8s responda y permita `kubectl get nodes`.

También falla temprano si el site entra en estados terminales como:

- `FAILED`
- `FAILED_INACTIVE`
- `ERROR_IN_ORCHESTRATION`
- `VALIDATION_FAILED`
- `ERROR_DELETING_CLOUD_RESOURCES`
- `ERROR_UPDATING_CLOUD_RESOURCES`

---

## Comprobaciones manuales recomendadas

### 1. Verificar el site en XC

En la consola de F5 XC revisa que el AWS App Stack Site llegue a estado operativo y que el mK8s asociado tenga nodos listos.

### 2. Revisar outputs del workspace `prerequisites`

Desde Terraform Cloud, abre el workspace `<workspace_prefix>-prerequisites` y revisa outputs como:

- `kiosk_address`
- `kiosk_user`
- `kiosk_password`
- `app_stack_name`
- `mk8s_cluster_name`

Esto te da el acceso RDP a la VM Windows y referencias del site desplegado.

### 3. Validar Kubernetes

Si generas un kubeconfig equivalente con una credencial válida de XC, puedes comprobar el estado de los workloads:

```bash
kubectl get ns
kubectl get pods -n <XC_NAMESPACE>
kubectl get svc -n <XC_NAMESPACE>
```

Deberías ver los componentes `mysql`, `wordpress` y `kiosk`.

### 4. Validar publicación interna

Desde una ubicación con alcance al site y resolución del dominio interno, comprueba:

```bash
curl -H 'Host: kiosk.<XC_NAMESPACE>.buytime.internal' http://<site-vip-o-ruta-de-prueba>/
curl -H 'Host: recommendations.<XC_NAMESPACE>.buytime.internal' http://<site-vip-o-ruta-de-prueba>/
```

La forma exacta de acceso depende de cómo consumas el site en tu laboratorio. En muchos escenarios prácticos la validación se hace desde la VM Windows kiosk o desde cargas conectadas al mismo site.

---

## Consideraciones operativas

- El workflow no tiene por ahora un workflow de destroy dedicado asociado a este caso.
- La VM Windows kiosk abre `3389/tcp` a `0.0.0.0/0`; para entornos no demo conviene restringir ese acceso.
- La credencial temporal del kubeconfig se elimina al final con `if: always()`, lo que reduce exposición residual aunque el despliegue falle.
- El origin `recommendations` depende del hostname externo `recommendations.buytime.sr.f5-cloud-demo.com`; si ese servicio no responde, el LB quedará creado pero el backend no estará sano.

---

## Resumen corto

`deploy-aws-module-1.yml` es un workflow de bootstrap completo para un laboratorio sobre **F5 XC App Stack en AWS**. Primero prepara infraestructura y site; después accede temporalmente al **mK8s**, despliega **Buytime Module 1** y publica dos endpoints internos para la aplicación.