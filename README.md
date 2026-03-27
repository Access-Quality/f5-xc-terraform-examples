<img width="2000" height="0" alt="" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">

# F5 Distributed Cloud -- Ejemplos de Automatización

## Descripción General

Ejemplos de despliegues de F5 Distributed Cloud (XC) utilizando Terraform. Los siguientes casos de uso están cubiertos en este proyecto:

---

## Casos de Uso

### 1. API + WAF + Bot Defense en RE (Aplicación en AWS) — `waf-re-aws-apply.yml`

Despliega un **Web Application Firewall (WAF), API Protection y Bot Defense sobre el Regional Edge (RE) de F5 Distributed Cloud**, protegiendo la aplicación **Arcadia Finance** que corre en una instancia EC2 dentro de un VPC en AWS. El tráfico de internet pasa por el RE global de F5 XC antes de llegar a la aplicación, sin necesidad de instalar un Customer Edge en la infraestructura del cliente. El HTTP Load Balancer se publica con una VIP pública en el RE; la WAF policy opera en **modo monitoreo** (`XC_WAF_BLOCKING = false`). Adicionalmente, se activa **API Discovery** (detección automática de endpoints), **API Protection** (validación en **modo report** sin bloqueo, para permitir el flujo completo de la UI) y **Bot Defense** (detección de clientes automatizados en **modo flag**, registrando eventos sin interrumpir el login desde el browser; configurable vía `XC_BOT_DEFENSE`).

👉 [Ver guía completa](readme/README-waf-re-aws-apply.md)

---

### 2. WAF on CE AWS — `waf-on-ce-aws-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre un Customer Edge (CE) de F5 XC en AWS**, protegiendo la aplicación **Online Boutique** que corre en un clúster EKS privado. El tráfico de internet es inspeccionado por F5 XC directamente en el CE (sin pasar por el Regional Edge), con un HTTP Load Balancer configurado como punto de entrada. Toda la infraestructura se provisiona desde cero con Terraform a través de cuatro workspaces de Terraform Cloud con estado remoto compartido: AWS Infra, EKS Cluster, Boutique App y F5 XC.

👉 [Ver guía completa](readme/README-waf-on-ce-aws-apply.md)

---

### 3. WAF on CE Azure — `waf-on-ce-az-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre un Customer Edge (CE) de F5 XC en Azure**, protegiendo una aplicación (Online Boutique) que corre en un clúster AKS privado. El tráfico de internet es inspeccionado por F5 XC directamente en el CE (sin pasar por Regional Edge), con un HTTP Load Balancer configurado como punto de entrada. Toda la infraestructura se provisiona desde cero con Terraform y tres workspaces de Terraform Cloud con estado remoto compartido.

👉 [Ver guía completa](readme/README-waf-on-ce-az-apply.md)

---

### 4. WAF en RE + AppConnect AWS — `waf-re-ac-aws-vm-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre el Regional Edge (RE) de F5 Distributed Cloud con AppConnect**, protegiendo la aplicación **DVWA** (Damn Vulnerable Web Application) que corre en una instancia EC2 dentro de un VPC privado en AWS. La aplicación **no necesita una IP pública** y se instala un **Customer Edge (CE) en AWS**: el tráfico llega al RE global de F5 XC y se reenvía a la app a través de un túnel cifrado establecido por el CE. Esto permite exponer aplicaciones en subredes privadas sin abrir puertos al exterior, combinando seguridad WAF en el RE con conectividad AppConnect.

👉 [Ver guía completa](readme/README-waf-re-ac-aws-vm-apply.md)

---

### 5. API WAF en RE para CE dentro de EKS — `f5xc-api-ce-eks-apply.yml`

Despliega una solución de **seguridad de APIs sobre el Regional Edge (RE) de F5 Distributed Cloud**, protegiendo la aplicación **crAPI** (Completely Ridiculous API) que corre en un clúster EKS en AWS. Se instala un **Customer Edge (CE) de F5 XC dentro del clúster EKS** para establecer conectividad segura entre la infraestructura privada y el plano global de XC. F5 XC aplica inspección de tráfico API con WAF, descubrimiento automático de endpoints (**API Discovery**), detección de anomalías y políticas de seguridad basadas en esquema OpenAPI. Toda la infraestructura se provisiona con Terraform a través de cinco workspaces de Terraform Cloud con estado remoto compartido: AWS Infra, EKS Cluster, crAPI App, F5 XC CE y F5 XC API Security.

👉 [Ver guía completa](readme/README-f5xc-api-ce-eks-apply.md)

---

### 6. MCN Network Connect — `teachable-01-mc-networkconnect-apply.yml`

Implementa conectividad de red **Multi-Cloud Networking (MCN)** entre AWS y Azure utilizando F5 Distributed Cloud como plano de control. Despliega nodos Customer Edge (CE) dentro del VPC/VNET del cliente, establece un túnel cifrado entre ambas nubes a través de la Global Virtual Network de XC (sin VPNs tradicionales ni peering directo), y aplica políticas de seguridad distribuidas mediante un Enhanced Firewall que permite micro-segmentación del tráfico este-oeste entre nubes.

👉 [Ver guía completa](readme/README-teachable-01-mcn-networkconnect-apply.md)

---

### 7. Bookinfo SMCN — `bookinfo-smcn-apply.yaml`

Despliega una **aplicación distribuida multi-cloud** donde los microservicios de Bookinfo corren en dos clústeres Kubernetes en diferentes nubes (EKS en AWS y AKS en Azure). F5 Distributed Cloud actúa como plano de conectividad y entrega de aplicaciones: conecta ambos clústeres sin VPNs, expone la app mediante HTTP Load Balancers de XC, y protege el tráfico con una capa **WAF** que bloquea ataques XSS, SQLi y amenazas OWASP directamente en el plano de distribución.

👉 [Ver guía completa](readme/README-bookinfo-smcn-apply.md)

---

### 8. Seguridad en RE para Arcadia + DVWA + Boutique + crAPI + Mailhog en AWS — `sec-re-aws-todas-apply.yml`

Despliega una solucion de **seguridad en el Regional Edge (RE) de F5 Distributed Cloud** para **cinco aplicaciones distintas publicadas desde una sola instancia EC2** de AWS: **Arcadia Finance**, **DVWA**, **Online Boutique**, **crAPI** y **Mailhog**. Cada aplicacion se expone con su propio FQDN, `ARCADIA_DOMAIN`, `DVWA_DOMAIN`, `BOUTIQUE_DOMAIN`, `CRAPI_DOMAIN` y `MAILHOG_DOMAIN`, pero todas comparten la misma VM y el mismo Elastic IP. Dentro de la instancia corre un **nginx instalado en el host** que enruta por `Host` hacia contenedores Docker publicados solo en `127.0.0.1`, lo que simplifica el health check y deja el puerto de origen fijo en `80`.

En F5 XC se crea **un solo HTTP Load Balancer** que anuncia los cinco dominios y apunta a **un solo origin pool**. Sobre ese LB se aplican controles globales de seguridad:

- **WAF** global en modo bloqueo o report segun `XC_WAF_BLOCKING`
- **API Discovery** global si `XC_API_DISCOVERY=true`
- **API Protection** global en modo report si `XC_API_PROTECTION=true`
- **Bot Defense** opcional para Arcadia sobre `POST /trading/auth.php`

Las especificaciones OpenAPI se cargan de forma opcional al object store de XC para **Arcadia** y **crAPI** mediante las variables `XC_UPLOAD_ARCADIA_API_SPEC` y `XC_UPLOAD_CRAPI_API_SPEC`. **Mailhog** queda expuesto como interfaz web de apoyo para revisar los correos generados por crAPI. El workflow construye dinamicamente la lista de specs que Terraform debe asociar al load balancer y aborta si se intenta activar API Protection sin haber subido al menos una spec.

El caso incluye ademas validaciones de readiness tanto contra el origen directo como contra los endpoints publicos, de forma que el workflow no termina correctamente hasta comprobar que las cinco aplicaciones responden.

👉 [Ver guía completa](readme/README-sec-re-aws-todas-apply.md)

---

### Comparativa de Arquitectura por Caso de Uso

La siguiente tabla resume la topología de cada caso: dónde se inspecciona el tráfico, si fluye por el Regional Edge global de F5, si se instala un Customer Edge en el entorno del cliente y si la aplicación puede permanecer en una red privada sin IP pública expuesta.

| Caso | Workflow | Nombre del workflow | Aplicación | Pruebas de seguridad | Punto de inspección | Tráfico pasa por RE | CE en cliente | AppConnect (túnel RE→CE) | App sin IP pública | Dónde corre la app | Nube |
| ---- | -------- | ------------------- | ---------- | :------------------: | ------------------- | :-----------------: | :-----------: | :----------------------: | :----------------: | ------------------ | ---- |
| 1 | `waf-re-aws-apply.yml` | API + WAF + BD en RE para VM en AWS | Arcadia Finance | WAF · API · BD | **RE** (Regional Edge) | ✅ | ❌ | ❌ | ❌ | VM (EC2) | AWS |
| 2 | `waf-on-ce-aws-apply.yml` | WAF on CE AWS | Online Boutique | WAF | **CE** (Customer Edge) | ❌ | ✅ EKS | ❌ | ✅ | Clúster EKS | AWS |
| 3 | `waf-on-ce-az-apply.yml` | WAF en CE AZ | Online Boutique | WAF | **CE** (Customer Edge) | ❌ | ✅ AKS | ❌ | ✅ | Clúster AKS | Azure |
| 4 | `waf-re-ac-aws-vm-apply.yml` | WAF en RE + AppConnect AWS | DVWA | WAF | **RE + CE** | ✅ | ✅ EC2 | ✅ | ✅ | VM (EC2) | AWS |
| 5 | `f5xc-api-ce-eks-apply.yml` | API WAF en RE para CE dentro de EKS | crAPI | WAF · API | **RE + CE** | ✅ | ✅ CE dentro del clúster EKS | ✅ | ✅ | Clúster EKS | AWS |
| 6 | `teachable-01-mc-networkconnect-apply.yml` | Teachable 01-mcn-networkconnect | — (MCN) | — | **CE** (MCN este-oeste) | ✅ Global VN | ✅ AWS + Azure | ❌ | ✅ | VMs en AWS y Azure | AWS + Azure |
| 7 | `bookinfo-smcn-apply.yaml` | Secure Multi-Cloud Networking | Bookinfo | WAF | **RE + CE** | ✅ | ✅ EKS + AKS | ✅ | ✅ | Clústeres EKS + AKS | AWS + Azure |
| 8 | `sec-re-aws-todas-apply.yml` | Seguridad en RE para Arcadia + DVWA + Boutique + crAPI + Mailhog en AWS | Arcadia Finance + DVWA + Online Boutique + crAPI + Mailhog | WAF · API · BD | **RE** (Regional Edge) | ✅ | ❌ | ❌ | ❌ | VM (EC2) compartida | AWS |

> **Pruebas de seguridad:** WAF = Web Application Firewall (SQLi, XSS, RCE…) · API = API Discovery + API Protection · BD = Bot Defense

**Glosario:**
- **RE (Regional Edge):** PoP global de F5. El tráfico de internet fluye por infraestructura de F5 antes de llegar a la aplicación.
- **CE (Customer Edge):** Nodo desplegado en la infraestructura del cliente. Inspección local; el plano de control siempre conecta con F5 XC cloud.
- **AppConnect:** El tráfico entra al RE global y se reenvía a la app a través de un túnel cifrado hasta el CE. La app no necesita IP pública.
- **Global VN (MCN):** Red virtual global de F5 XC que conecta múltiples CEs entre nubes distintas sin VPNs ni peering directo.

---

### Guía de Pruebas de Seguridad por Aplicación

Cada caso de uso incluye una aplicación diferente. La siguiente tabla resume qué tipo de pruebas encajan mejor con cada una:

| Tipo de prueba                             | Arcadia Finance (caso 1) | DVWA (caso 4) | Online Boutique (casos 2 y 3) | crAPI (caso 5) | Arcadia + DVWA + Boutique + crAPI (caso 8) |
| ------------------------------------------ | :----------------------: | :-----------: | :---------------------------: | :------------: | :---------------------: |
| WAF — SQLi, XSS, Command Injection         | ✅                        | ✅ Ideal       | ⚠️ Limitado                   | ⚠️ Parcial     | ✅ Ideal                |
| WAF — File upload / RCE                    | ❌                        | ✅ Ideal       | ❌                             | ❌              | ✅ Válido               |
| WAF — Brute force de login                 | ✅                        | ✅ Ideal       | ⚠️                            | ✅              | ✅ Ideal                |
| Bot Defense (credential stuffing)          | ✅ Ideal                  | ✅ Válido      | ⚠️ Limitado                   | ✅ Válido       | ✅ Válido               |
| API Discovery (inventario de endpoints)    | ✅ Ideal                  | ❌             | ❌                             | ✅ Ideal        | ✅ Válido               |
| API Protection (validación OpenAPI)        | ✅ Ideal                  | ❌             | ❌                             | ✅ Ideal        | ✅ Válido               |
| SSRF + OpenAPI Validation                  | ❌                        | ❌             | ❌                             | ✅ Ideal        | ⚠️ Parcial             |
| BOLA / IDOR (OWASP API Top 10)             | ❌                        | ❌             | ❌                             | ✅ Ideal        | ⚠️ Parcial             |
| Rate limiting / abuso de API               | ✅ Válido                 | ✅ Válido      | ✅ Ideal                       | ✅ Ideal        | ✅ Ideal                |
| DDoS L7 (flood HTTP)                       | ✅ Válido                 | ✅ Válido      | ✅ Ideal                       | ✅ Válido       | ✅ Ideal                |
| OWASP Web Top 10 (módulos didácticos)      | ❌                        | ✅ Ideal       | ❌                             | ❌              | ✅ Ideal                |

> Cada README de caso incluye una sección **"Pruebas de seguridad"** con ejemplos curl específicos para la aplicación correspondiente.

---

### Archivos de Flujo de Trabajo

| **Workflow**                               | **Capacidades**                          | **Guía**                                                         |
| ------------------------------------------ | ---------------------------------------- | ----------------------------------------------------------------- |
| `waf-re-aws-apply.yml`                     | WAF + API Discovery + API Protection + Bot Defense | [README](readme/README-waf-re-aws-apply.md)                       |
| `waf-on-ce-aws-apply.yml`                  | WAF en CE                                | [README](readme/README-waf-on-ce-aws-apply.md)                    |
| `waf-on-ce-az-apply.yml`                   | WAF en CE                                | [README](readme/README-waf-on-ce-az-apply.md)                     |
| `waf-re-ac-aws-vm-apply.yml`               | WAF en RE + AppConnect                   | [README](readme/README-waf-re-ac-aws-vm-apply.md)                 |
| `f5xc-api-ce-eks-apply.yml`                | API Security + WAF en RE + CE en EKS     | [README](readme/README-f5xc-api-ce-eks-apply.md)                  |
| `teachable-01-mc-networkconnect-apply.yml` | MCN Network Connect                      | [README](readme/README-teachable-01-mcn-networkconnect-apply.md)  |
| `bookinfo-smcn-apply.yaml`                 | Multi-cloud + WAF                        | [README](readme/README-bookinfo-smcn-apply.md)                    |
| `sec-re-aws-todas-apply.yml`               | WAF global + API Discovery/Protection para Arcadia y crAPI + Bot Defense opcional + Mailhog publico | [README](readme/README-sec-re-aws-todas-apply.md)           |

---

## Historial de Cambios

### 2026-03-27
- **Seguridad en RE para Arcadia + DVWA + Boutique + crAPI + Mailhog en AWS** (`sec-re-aws-todas-apply.yml` / `sec-re-aws-todas-destroy.yml`): el caso compartido en una sola VM EC2 de AWS publica ahora tambien **Mailhog** con un quinto FQDN (`MAILHOG_DOMAIN`) sobre el mismo nginx del host y el mismo HTTP Load Balancer de F5 XC. Esto permite acceder desde internet a la interfaz web de Mailhog usada por crAPI, manteniendo el patron de enrutamiento por `Host` y las validaciones de readiness sobre origen y endpoints publicos.

### 2026-03-26
- **API + WAF + Bot Defense en RE AWS** (`waf-re-aws-apply.yml` / `waf-re-aws-destroy.yml`): workflows renombrados a `API + WAF + BD` para reflejar que incluyen **WAF**, **API Discovery**, **API Protection** y **Bot Defense** (opcional vía variable `XC_BOT_DEFENSE`). Se agregó `VOLT_API_P12_FILE` al job `terraform_xc` de ambos workflows para correcta autenticación del provider de F5 XC.

### 2026-03-25
- **WAF on CE Azure** (`waf-on-ce-az-apply.yml` / `waf-on-ce-az-destroy.yml`): la variable de GitHub `APP_DOMAIN` fue renombrada a `BOUTIQUE_DOMAIN` para mayor claridad sobre la aplicación protegida. Actualizar el valor en *Settings → Secrets and variables → Variables* del repositorio.
- **WAF on CE AWS** (`waf-on-ce-aws-apply.yml` / `waf-on-ce-aws-destroy.yml`): nombre del workflow actualizado a `WAF on CE AWS - Deploy / Destroy` para seguir la convención de nomenclatura del resto de workflows.

---
