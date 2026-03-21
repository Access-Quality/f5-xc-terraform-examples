# F5 Distributed Cloud -- Ejemplos de Automatización

## Descripción General

Ejemplos de despliegues de F5 Distributed Cloud (XC) utilizando Terraform. Los siguientes casos de uso están cubiertos en este proyecto:

---

## Casos de Uso

### 1. MCN Network Connect — `teachable-01-mc-networkconnect-apply.yml`

Implementa conectividad de red **Multi-Cloud Networking (MCN)** entre AWS y Azure utilizando F5 Distributed Cloud como plano de control. Despliega nodos Customer Edge (CE) dentro del VPC/VNET del cliente, establece un túnel cifrado entre ambas nubes a través de la Global Virtual Network de XC (sin VPNs tradicionales ni peering directo), y aplica políticas de seguridad distribuidas mediante un Enhanced Firewall que permite micro-segmentación del tráfico este-oeste entre nubes.

👉 [Ver guía completa](readme/README-teachable-01-mcn-networkconnect-apply.md)

---

### 2. Bookinfo SMCN — `bookinfo-smcn-apply.yaml`

Despliega una **aplicación distribuida multi-cloud** donde los microservicios de Bookinfo corren en dos clústeres Kubernetes en diferentes nubes (EKS en AWS y AKS en Azure). F5 Distributed Cloud actúa como plano de conectividad y entrega de aplicaciones: conecta ambos clústeres sin VPNs, expone la app mediante HTTP Load Balancers de XC, y protege el tráfico con una capa **WAF** que bloquea ataques XSS, SQLi y amenazas OWASP directamente en el plano de distribución.

👉 [Ver guía completa](readme/README-bookinfo-smcn-apply.md)

---

### 3. WAF on CE Azure — `waf-on-ce-az-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre un Customer Edge (CE) de F5 XC en Azure**, protegiendo una aplicación (Online Boutique) que corre en un clúster AKS privado. El tráfico de internet es inspeccionado por F5 XC directamente en el CE (sin pasar por Regional Edge), con un HTTP Load Balancer configurado como punto de entrada. Toda la infraestructura se provisiona desde cero con Terraform y tres workspaces de Terraform Cloud con estado remoto compartido.

👉 [Ver guía completa](readme/README-waf-on-ce-az-apply.md)

---

### 4. WAF en RE (Aplicación en AWS) — `waf-re-aws-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre el Regional Edge (RE) de F5 Distributed Cloud**, protegiendo la aplicación **Arcadia Finance** que corre en una instancia EC2 dentro de un VPC en AWS. A diferencia del caso anterior, el tráfico de internet pasa por el RE global de F5 XC antes de llegar a la aplicación, sin necesidad de instalar un Customer Edge en la infraestructura del cliente. El HTTP Load Balancer se publica con una VIP pública en el RE y la WAF policy puede configurarse en modo bloqueo o detección.

👉 [Ver guía completa](readme/README-waf-re-aws-apply.md)

---

### 5. WAF en RE + AppConnect (VM en AWS) — `waf-re-ac-aws-vm-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre el Regional Edge (RE) de F5 Distributed Cloud con AppConnect**, protegiendo la aplicación **DVWA** (Damn Vulnerable Web Application) que corre en una instancia EC2 dentro de un VPC privado en AWS. A diferencia del caso 4, la aplicación **no necesita una IP pública** y se instala un **Customer Edge (CE) en AWS**: el tráfico llega al RE global de F5 XC y se reenvía a la app a través de un túnel cifrado establecido por el CE. Esto permite exponer aplicaciones en subredes privadas sin abrir puertos al exterior, combinando seguridad WAF en el RE con conectividad AppConnect.

👉 [Ver guía completa](readme/README-waf-re-ac-aws-vm-apply.md)

---

### 6. WAF on CE AWS — `waf-on-ce-aws-apply.yml`

Despliega un **Web Application Firewall (WAF) sobre un Customer Edge (CE) de F5 XC en AWS**, protegiendo la aplicación **Online Boutique** que corre en un clúster EKS privado. El tráfico de internet es inspeccionado por F5 XC directamente en el CE (sin pasar por el Regional Edge), con un HTTP Load Balancer configurado como punto de entrada. Toda la infraestructura se provisiona desde cero con Terraform a través de cuatro workspaces de Terraform Cloud con estado remoto compartido: AWS Infra, EKS Cluster, Boutique App y F5 XC.

👉 [Ver guía completa](readme/README-waf-on-ce-aws-apply.md)

---

### Archivos de Flujo de Trabajo

| **Workflow**                               | **Guía**                                                              |
| ------------------------------------------ | --------------------------------------------------------------------- |
| `teachable-01-mc-networkconnect-apply.yml` | [README](readme/README-teachable-01-mcn-networkconnect-apply.md)      |
| `bookinfo-smcn-apply.yaml`                 | [README](readme/README-bookinfo-smcn-apply.md)                        |
| `waf-on-ce-az-apply.yml`                   | [README](readme/README-waf-on-ce-az-apply.md)                         |
| `waf-re-aws-apply.yml`                     | [README](readme/README-waf-re-aws-apply.md)                           |
| `waf-re-ac-aws-vm-apply.yml`               | [README](readme/README-waf-re-ac-aws-vm-apply.md)                     |
| `waf-on-ce-aws-apply.yml`                  | [README](readme/README-waf-on-ce-aws-apply.md)                        |

---
