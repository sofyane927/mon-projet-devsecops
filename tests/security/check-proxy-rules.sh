#!/usr/bin/env bash
#
# Test des 4 règles du reverse proxy (Challenge 5) :
#   1. Load balancing (réponses réparties sur web1 ET web2)
#   2. Méthodes HTTP : seules GET/POST autorisées (sinon 403)
#   3. Rate limiting : 10 req/min/IP (sinon 429)
#   4. Mini-WAF : patterns suspects bloqués (403)
#
# Échoue (exit 1) si une règle ne fonctionne pas.
# Usage : ./check-proxy-rules.sh [URL]   (défaut : http://localhost:8080)
#
set -uo pipefail

URL="${1:-http://localhost:8080}"
fail=0

# Helper : renvoie le code HTTP d'une requête
code() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

echo "================================================================"
echo " Tests des règles du reverse proxy : ${URL}"
echo "================================================================"

# --- Règle 4 : mini-WAF (ne consomme pas le quota de rate limiting) ---
echo
echo "## Règle 4 — mini-WAF (403 attendu)"
declare -A waf=(
  ["XSS"]="${URL}/?q=<script>alert(1)</script>"
  ["SQLi UNION SELECT"]="${URL}/?id=1%20union%20select%20pass%20from%20users"
  ["Path traversal"]="${URL}/?file=../../etc/passwd"
  ["SELECT FROM"]="${URL}/?q=select%20name%20from%20admin"
)
for name in "${!waf[@]}"; do
  c=$(code "${waf[$name]}")
  if [ "$c" = "403" ]; then echo "  ✅ ${name} -> 403"; else echo "  ❌ ${name} -> ${c} (attendu 403)"; fail=1; fi
done

# --- Règle 1 : load balancing (web1 ET web2 doivent apparaître) ---
# Requêtes espacées (~2s) avec arrêt anticipé : robuste face au round-robin
# "à froid" et au rate limiting (laisse le temps aux jetons de se reconstituer).
echo
echo "## Règle 1 — load balancing (web1 ET web2 attendus)"
seen=""
for i in $(seq 1 12); do
  b=$(curl -s -D - -o /dev/null "${URL}/" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-backend"{print $2}')
  [ -n "$b" ] && seen="${seen} ${b}"
  if echo "${seen}" | grep -q "web1" && echo "${seen}" | grep -q "web2"; then break; fi
  sleep 2
done
echo "  Backends vus :$(echo "${seen}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
if echo "${seen}" | grep -q "web1" && echo "${seen}" | grep -q "web2"; then
  echo "  ✅ Répartition sur web1 et web2"
else
  echo "  ❌ Load balancing KO (vus :${seen} )"; fail=1
fi

# --- Règle 2 : méthodes HTTP ---
echo
echo "## Règle 2 — méthodes HTTP"
g=$(code "${URL}/")
if [ "$g" = "200" ]; then echo "  ✅ GET -> 200"; else echo "  ❌ GET -> ${g} (attendu 200)"; fail=1; fi
p=$(code -X POST "${URL}/")
if [ "$p" != "403" ]; then echo "  ✅ POST -> ${p} (non bloqué)"; else echo "  ❌ POST -> 403 (ne devrait pas être bloqué)"; fail=1; fi
for m in PUT DELETE OPTIONS PATCH; do
  c=$(code -X "$m" "${URL}/")
  if [ "$c" = "403" ]; then echo "  ✅ ${m} -> 403"; else echo "  ❌ ${m} -> ${c} (attendu 403)"; fail=1; fi
done

# --- Règle 3 : rate limiting (un 429 doit apparaître) ---
echo
echo "## Règle 3 — rate limiting (429 attendu)"
got429=0
for i in $(seq 1 20); do
  c=$(code "${URL}/")
  if [ "$c" = "429" ]; then got429=1; fi
done
if [ "$got429" = "1" ]; then echo "  ✅ 429 obtenu (rate limiting actif)"; else echo "  ❌ Aucun 429 (rate limiting KO)"; fail=1; fi

echo
if [ "$fail" -ne 0 ]; then
  echo "💥 ÉCHEC : au moins une règle du proxy ne fonctionne pas."
  exit 1
fi
echo "🎉 SUCCÈS : les 4 règles du reverse proxy fonctionnent."
