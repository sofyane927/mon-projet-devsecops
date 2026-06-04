#!/usr/bin/env bash
#
# Test de sécurité : vérifie la présence des en-têtes de sécurité HTTP
# recommandés par l'OWASP. Échoue (exit 1) si un en-tête est manquant.
#
# Usage : ./check-headers.sh [URL]   (défaut : http://localhost:8080)
#
set -euo pipefail

URL="${1:-http://localhost:8080}"
echo "🔍 Vérification des en-têtes de sécurité sur ${URL}"
echo

# Récupération des en-têtes de la réponse (-s silencieux, -I headers seulement)
HEADERS="$(curl -sIL "${URL}")"
echo "----- En-têtes reçus -----"
echo "${HEADERS}"
echo "--------------------------"
echo

# En-têtes de sécurité obligatoires
REQUIRED_HEADERS=(
  "X-Frame-Options"
  "X-Content-Type-Options"
  "Referrer-Policy"
  "Permissions-Policy"
  "Content-Security-Policy"
  "Strict-Transport-Security"
)

missing=0
for header in "${REQUIRED_HEADERS[@]}"; do
  # grep insensible à la casse, en début de ligne
  if echo "${HEADERS}" | grep -iq "^${header}:"; then
    echo "✅ ${header} : présent"
  else
    echo "❌ ${header} : MANQUANT"
    missing=1
  fi
done

# Vérification bonus : la version de Nginx ne doit pas fuiter
if echo "${HEADERS}" | grep -iqE "^Server:\s*nginx/[0-9]"; then
  echo "⚠️  Server : la version de Nginx est exposée (server_tokens off ?)"
  missing=1
else
  echo "✅ Server : version non exposée"
fi

echo
if [ "${missing}" -ne 0 ]; then
  echo "💥 ÉCHEC : des en-têtes de sécurité sont manquants ou une info fuit."
  exit 1
fi
echo "🎉 SUCCÈS : tous les en-têtes de sécurité sont présents."
