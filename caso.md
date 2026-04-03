# Casos de Uso Consolidados

Este documento resume los 10 casos actualmente descritos en el README principal del repositorio y agrega 5 casos adicionales basados en guias internas y externas relacionadas con application delivery, AppConnect, MCN y NAT.

---

## Application Delivery y Seguridad

## Caso 1. API + WAF + Bot Defense en RE para Arcadia en AWS

**Workflow:** `waf-re-aws-apply.yml`

Despliega proteccion sobre el **Regional Edge (RE)** de F5 Distributed Cloud para la aplicacion **Arcadia Finance** ejecutada en una VM EC2 dentro de AWS. El flujo incorpora **WAF**, **API Discovery**, **API Protection** y **Bot Defense** opcional, con un **HTTP Load Balancer publico** anunciado desde el RE global.

**Puntos clave:**
- La aplicacion permanece en AWS y el trafico entra primero al RE global de F5 XC.
- No requiere Customer Edge en la infraestructura del cliente.
- API Protection opera en modo report para no interrumpir la UI.

**Guia local:** [readme/README-waf-re-aws-apply.md](readme/README-waf-re-aws-apply.md)

---

## Caso 5. WAF on CE AWS para Online Boutique

**Workflow:** `waf-on-ce-aws-apply.yml`

Despliega un **WAF sobre Customer Edge (CE)** en AWS para proteger **Online Boutique** sobre un cluster **EKS privado**. El trafico se inspecciona localmente en el CE y no en el RE.

**Puntos clave:**
- Modelo de proteccion en el edge del cliente.
- La app corre en Kubernetes privado dentro de AWS.
- Se apoya en workspaces de Terraform Cloud con estado remoto compartido.

**Guia local:** [readme/README-waf-on-ce-aws-apply.md](readme/README-waf-on-ce-aws-apply.md)

---

## Caso 6. WAF on CE Azure para Online Boutique

**Workflow:** `waf-on-ce-az-apply.yml`

Replica el patron del caso 2, pero en **Azure**, desplegando un **Customer Edge** para proteger **Online Boutique** sobre **AKS privado**.

**Puntos clave:**
- Inspeccion local en CE sin pasar por el RE.
- Muestra el mismo patron de seguridad trasladado a Azure.
- Terraform orquesta toda la infraestructura y la integracion con XC.

**Guia local:** [readme/README-waf-on-ce-az-apply.md](readme/README-waf-on-ce-az-apply.md)

---

## Caso 7. WAF en RE + AppConnect para DVWA en AWS

**Workflow:** `waf-re-ac-aws-vm-apply.yml`

Protege **DVWA** en una **VM privada de AWS** usando **WAF en el Regional Edge** y **AppConnect** mediante un **Customer Edge** desplegado en AWS.

**Puntos clave:**
- La aplicacion no necesita IP publica.
- El trafico entra por el RE y viaja por un tunel cifrado hasta el CE.
- Combina proteccion centralizada con conectividad privada hacia la app.

**Guia local:** [readme/README-waf-re-ac-aws-vm-apply.md](readme/README-waf-re-ac-aws-vm-apply.md)

---

## Caso 8. API WAF en RE para crAPI con CE dentro de EKS

**Workflow:** `f5xc-api-ce-eks-apply.yml`

Despliega seguridad de APIs para **crAPI** en **EKS** con inspeccion en **RE**, mientras un **CE dentro del cluster** aporta conectividad privada con XC.

**Puntos clave:**
- Incluye WAF, API Discovery y politicas basadas en OpenAPI.
- El CE vive dentro de EKS para enlazar el entorno privado con el plano global.
- Es un caso enfocado en seguridad de APIs mas que en una app web tradicional.

**Guia local:** [readme/README-f5xc-api-ce-eks-apply.md](readme/README-f5xc-api-ce-eks-apply.md)

---

## Caso 12. App Delivery & Security para workloads distribuidos en entornos hibridos

**Fuente local:** `workflow-guides/application-delivery-security/workload/README.rst`

Este caso describe un patron de **application delivery y seguridad uniforme** para workloads repetidos en distintos entornos como **VMware**, **OpenShift**, **Nutanix** y nubes publicas, usando **Secure Mesh Site v2**, **Customer Edge** y **Regional Edge** de F5 Distributed Cloud.

**Objetivo general:**
- Mantener politicas consistentes de entrega y seguridad para aplicaciones desplegadas en varias plataformas.
- Facilitar la incorporacion de nuevos workloads sin cambiar el modelo operativo.
- Proteger aplicaciones como **Juice Shop**, **DVWA** y **NGINX** con WAF y observabilidad centralizada.

**Puntos clave:**
- Cubre entornos on-prem y cloud dentro de un unico modelo de conectividad.
- Expone como agregar nuevas instancias de workloads ya existentes en VMware, OCP, Nutanix y Azure.
- Refuerza el patron de apps no expuestas directamente, conectadas por CE mediante Site Local Inside.

**Guia local:** [workflow-guides/application-delivery-security/workload/README.rst](workflow-guides/application-delivery-security/workload/README.rst)

---

## Escenarios Consolidados en AWS

## Caso 2. Seguridad en RE para Arcadia + DVWA + Boutique + crAPI en una sola VM AWS

**Workflow:** `sec-re-aws-todas-apply.yml`

Consolida **cuatro aplicaciones** principales y **Mailhog** en una sola instancia EC2 de AWS, con **nginx en el host** y un **unico HTTP Load Balancer** en el RE de F5 XC.

**Puntos clave:**
- Una sola VM publica multiples apps usando routing por `Host` desde nginx.
- WAF global, API Discovery y API Protection para Arcadia y crAPI.
- Incluye validaciones de readiness del origen y de los endpoints publicos.

**Guia local:** [readme/README-sec-re-aws-todas-apply.md](readme/README-sec-re-aws-todas-apply.md)

---

## Caso 3. Seguridad en RE para Arcadia + DVWA + Boutique + crAPI en AWS sin nginx

**Workflow:** `sec-re-aws-todas-sin-ngix-apply.yml`

Mantiene el modelo de una sola VM compartida, pero elimina **nginx** y mueve la logica de enrutamiento hacia el **HTTP Load Balancer** de XC usando varios origin pools.

**Puntos clave:**
- Cada servicio se expone en un puerto distinto del host.
- El LB de XC resuelve el backend por `Host` y `path`.
- Simplifica el host, pero abre mas puertos en el security group que el caso 8.

**Guia local:** [readme/README-sec-re-aws-todas-sin-nginx-apply.md](readme/README-sec-re-aws-todas-sin-nginx-apply.md)

---

## Caso 4. Seguridad en RE para Arcadia + DVWA + Boutique + crAPI en AWS con 4 LBs

**Workflow:** `sec-re-aws-todas-4lbs.yml`

Parte del mismo despliegue compartido del caso 9, pero divide la exposicion publica en **cuatro HTTP Load Balancers separados** para mejorar aislamiento logico por aplicacion.

**Puntos clave:**
- Arcadia, DVWA y Boutique tienen LB dedicado.
- crAPI comparte LB con Mailhog.
- Mantiene una sola VM en AWS, pero separa la capa de exposicion en XC.

**Guia local:** [readme/README-sec-re-aws-todas-4lbs-apply.md](readme/README-sec-re-aws-todas-4lbs-apply.md)

---

## Networking y Secure Multi-Cloud Networking

## Caso 9. MCN Network Connect entre AWS y Azure

**Workflow:** `teachable-01-mc-networkconnect-apply.yml`

**Puntos clave:**
- Despliega CE en ambas nubes.
- Conecta redes mediante la **Global Virtual Network** de XC.
- Permite micro-segmentacion y politicas de firewall distribuidas entre nubes.

**Guia local:** [readme/README-teachable-01-mcn-networkconnect-apply.md](readme/README-teachable-01-mcn-networkconnect-apply.md)

---

## Caso 10. Bookinfo SMCN en AWS y Azure

**Workflow:** `bookinfo-smcn-apply.yaml`

Despliega **Bookinfo** como aplicacion distribuida multi-cloud entre **EKS en AWS** y **AKS en Azure**, usando F5 XC para conectividad, exposicion y proteccion.

**Puntos clave:**
- Une dos clusters en nubes distintas sin VPNs tradicionales.
- Expone la aplicacion con HTTP Load Balancers de XC.
- Añade proteccion WAF contra amenazas OWASP en el plano de distribucion.

**Guia local:** [readme/README-bookinfo-smcn-apply.md](readme/README-bookinfo-smcn-apply.md)

---

## Caso 14. Secure Network Fabric con AWS TGW, VMware y segmentacion segura

**Fuente local:** `workflow-guides/smcn/secure-network-fabric/README.md`

Este caso implementa una **fabrica de red segura** sobre **Multi-Cloud Networking**, combinando **AWS TGW Site**, varios **VPCs**, un **Secure Mesh Site** en **VMware**, **Cloud Connect**, **Segment Connectors**, **Site Mesh Group** y politicas de **Enhanced Firewall**.

**Objetivo general:**
- Conectar VPCs de distintas cuentas y un datacenter VMware bajo una topologia comun.
- Segmentar trafico entre redes `prod`, `dev`, `shared` y `external`.
- Controlar el acceso entre segmentos con firewall distribuido y metodos network-centric y app-centric.

**Puntos clave:**
- Integra AWS y VMware dentro de un mismo tejido de red.
- Usa Cloud Connect para unir VPCs y Segment Connectors para definir conectividad permitida.
- Cierra el caso con politicas de firewall y un enfoque de Extranet tanto centrado en red como en aplicacion.

**Guia local:** [workflow-guides/smcn/secure-network-fabric/README.md](workflow-guides/smcn/secure-network-fabric/README.md)

---

## Caso 15. NAT para solapamiento IP, enmascaramiento y salida a internet

**Fuente local:** `workflow-guides/smcn/nat/README.md`

Este caso amplia el escenario de SMCN con politicas de **NAT** para resolver tres problemas frecuentes: **CIDRs solapados**, **enmascaramiento de IP origen** entre AWS y VMware, y **SNAT hacia internet** usando una **Elastic IP** del sitio TGW en AWS.

**Objetivo general:**
- Resolver conflictos de direccionamiento entre redes conectadas por MCN.
- Enmascarar IPs origen para simplificar politicas y proteger topologias internas.
- Estandarizar la salida a internet mediante SNAT sobre una IP publica controlada.

**Puntos clave:**
- Usa **Virtual Subnet NAT** para separar redes con rangos superpuestos.
- Aplica **SNAT Pool** para ocultar el origen del trafico entre AWS y VMware.
- Muestra un patron reutilizable de egress controlado con Elastic IP en AWS TGW Site.

**Guia local:** [workflow-guides/smcn/nat/README.md](workflow-guides/smcn/nat/README.md)

---

## Edge Compute, App Stack y GenAI

## Caso 11. Edge Compute y Enterprise Networking en AWS para BuyTime

**Fuente externa:** https://github.com/f5devcentral/xcawsedgedemoguide/blob/main/README.md

Este caso agrega una guia de referencia externa orientada a **Edge Compute**, **App Stack**, **MCN** y **App Connect** en AWS usando el escenario de **BuyTime**, una aplicacion tipo WooCommerce distribuida entre sucursal, nube publica y edge.

**Objetivo general:**
- Mostrar como desplegar y conectar componentes de una aplicacion distribuida entre **Retail Branch**, **Customer Edge** y **Regional Edge**.
- Usar **App Stack** para ejecutar workloads cerca del edge.
- Combinar conectividad privada, balanceo y servicios distribuidos sobre F5 XC.

**Resumen por modulos:**
- **Modulo 1:** despliega un kiosk de sucursal sobre **App Stack + mK8s**, crea un HTTP LB interno para `kiosk.branch-a.buytime.internal` y otro para `recommendations.branch-a.buytime.internal`, conectando el kiosco con un servicio externo de recomendaciones.
- **Modulo 2:** usa **Customer Edge** y **virtual K8s** para publicar el modulo de sincronizacion de inventario mediante un **TCP Load Balancer**, habilitando conectividad segura entre sucursal y backend central.
- **Modulo 3:** despliega la tienda online sobre **vK8s**, la expone con un **HTTP Load Balancer** publico y agrega un modulo de promociones tipo **Lightning Deals** usando **Regional Edge** y virtual sites RE/CE.

**Puntos clave:**
- Caso orientado a una arquitectura distribuida realista de retail.
- Combina App Stack, mK8s, CE, RE, vK8s y balanceadores HTTP/TCP.
- Sirve como referencia para patrones de edge compute, conectividad multi-entorno y exposicion de servicios distribuidos.

**Guia externa:** https://github.com/f5devcentral/xcawsedgedemoguide/blob/main/README.md

---

## Caso 13. GenAI distribuida con AppConnect y WAF entre AWS y GCP

**Fuente local:** `workflow-guides/smcn/genai-appconnect-waf/xc-console-demo-guide.rst`

Este caso conecta y protege una aplicacion **Generative AI** distribuida entre **AWS** y **GCP**. El servicio **LLM** corre en **EKS**, el frontend **GenAI** corre en **GKE**, y F5 XC se usa para publicar el servicio remoto como local, exponer la aplicacion y aplicar controles de seguridad.

**Objetivo general:**
- Conectar un frontend GenAI en GKE con un backend LLM en EKS sin usar NGINX Ingress Controller.
- Exponer la aplicacion externamente mediante balanceo de F5 XC.
- Mitigar la divulgacion de informacion sensible mediante **Data Guard** en el HTTP Load Balancer.

**Puntos clave:**
- Usa CE sobre Kubernetes en ambos clusters para conectividad entre nubes.
- Publica el servicio `llama.llm` desde EKS como servicio local para GKE.
- Incluye una prueba explicita de DLP antes y despues de habilitar Data Guard.

**Guia local:** [workflow-guides/smcn/genai-appconnect-waf/xc-console-demo-guide.rst](workflow-guides/smcn/genai-appconnect-waf/xc-console-demo-guide.rst)

---

## Resumen Rapido

| Caso | Patron principal | Ubicacion de inspeccion/conectividad | Aplicacion o dominio principal |
| ---- | ---------------- | ------------------------------------ | ------------------------------ |
| 1 | WAF + API + Bot Defense en RE | RE | Arcadia Finance |
| 2 | 4 apps en una VM con nginx | RE | Arcadia + DVWA + Boutique + crAPI |
| 3 | 4 apps en una VM sin nginx | RE | Arcadia + DVWA + Boutique + crAPI |
| 4 | 4 apps con 4 LBs | RE | Arcadia + DVWA + Boutique + crAPI |
| 5 | WAF en CE AWS | CE | Online Boutique en EKS |
| 6 | WAF en CE Azure | CE | Online Boutique en AKS |
| 7 | WAF en RE + AppConnect | RE + CE | DVWA |
| 8 | API Security en RE con CE en EKS | RE + CE | crAPI |
| 9 | MCN entre nubes | CE + Global VN | Redes AWS y Azure |
| 10 | App distribuida multi-cloud | RE + CE | Bookinfo |
| 11 | Edge Compute + App Stack + MCN | App Stack + CE + RE | BuyTime |
| 12 | Delivery y seguridad para workloads hibridos | CE + RE | Juice Shop + DVWA + NGINX |
| 13 | GenAI distribuida con AppConnect y WAF | CE en EKS + CE en GKE | LLM + frontend GenAI |
| 14 | Secure Network Fabric | AWS TGW + Secure Mesh + Segmentacion | VPCs AWS + VMware |
| 15 | NAT para MCN | NAT Policies + TGW Site | Overlap IP + SNAT + egress |