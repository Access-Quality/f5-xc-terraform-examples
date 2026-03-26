#!/usr/bin/env bash
# herramientas/test_ddos.sh
# Pruebas locales de Rate Limiting, HTTP Flood L7 y API Abuse contra un WAF F5 XC.
#
# Uso:
#   chmod +x herramientas/test_ddos.sh
#   ./herramientas/test_ddos.sh http://boutique.tudominio.com
set -euo pipefail

TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  echo "Uso: $0 <URL_objetivo>"
  echo "  Ejemplo: $0 http://boutique.tudominio.com"
  exit 1
fi

echo "=========================================="
echo " Target: ${TARGET}"
echo "=========================================="

# ── Instalar hey si no está disponible ────────────────────────────────
if ! command -v hey &>/dev/null; then
  echo "[*] 'hey' no encontrado — instalando via Homebrew..."
  brew install hey
fi

# ── TEST 1: Rate Limiting — burst desde una sola IP ───────────────────
echo ""
echo "=== TEST 1: Rate Limit — 300 requests, concurrencia 60 ==="
hey -n 300 -c 60 -m GET "${TARGET}/" | tee /tmp/rate_limit.txt

echo "--- Distribución de códigos de respuesta ---"
grep "Status code" /tmp/rate_limit.txt || true

if grep -qE "\[429\]|\[403\]" /tmp/rate_limit.txt; then
  echo "✓ PASS: El WAF bloqueó requests por rate limiting"
else
  echo "⚠ WARN: Sin bloqueos detectados — verifica la Rate Limit Policy en F5 XC"
fi

# ── TEST 2: DDoS L7 / HTTP Flood ──────────────────────────────────────
echo ""
echo "=== TEST 2: HTTP Flood — concurrencia 200 durante 30 segundos ==="
hey -z 30s -c 200 -m GET "${TARGET}/" | tee /tmp/flood.txt

if grep -qE "\[2[0-9]{2}\]|\[429\]|\[403\]" /tmp/flood.txt; then
  echo "✓ PASS: La aplicación sobrevivió el flood — WAF operativo"
else
  echo "✗ FAIL: Sin respuesta válida durante el flood"
  exit 1
fi

# ── TEST 3: API Endpoint Abuse ─────────────────────────────────────────
echo ""
echo "=== TEST 3: API Abuse — 100 requests con User-Agent sospechoso ==="
BLOCKED=0
for i in $(seq 1 100); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "${TARGET}/product/OLJCESPC7Z" \
    -H "User-Agent: python-requests/2.28.0" \
    -H "X-Forwarded-For: 10.0.0.$(( RANDOM % 255 ))")
  printf "Request %3d: HTTP %s\n" "$i" "$CODE"
  [[ "${CODE}" == "429" || "${CODE}" == "403" ]] && BLOCKED=$(( BLOCKED + 1 ))
done

echo ""
echo "Total bloqueados: ${BLOCKED}/100"
if [[ "${BLOCKED}" -gt 0 ]]; then
  echo "✓ PASS: WAF bloqueó ${BLOCKED} requests de abuso de API"
else
  echo "⚠ WARN: Sin bloqueos — configura Rate Limiting en el HTTP LB de F5 XC"
fi

echo ""
echo "=========================================="
echo " Pruebas finalizadas"
echo " Revisa los eventos en F5 XC Console:"
echo " Security → App Firewall → Security Events"
echo "=========================================="
