# Image de base officielle et légère (Alpine), version épinglée pour la sécurité
FROM nginx:1.27-alpine

# Copie de la page statique dans le répertoire servi par Nginx
COPY index.html /usr/share/nginx/html/index.html

# Nginx écoute sur le port 80 par défaut
EXPOSE 80

# Healthcheck simple pour vérifier que le serveur répond
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -q --spider http://localhost:80/ || exit 1

# Lancement de Nginx au premier plan
CMD ["nginx", "-g", "daemon off;"]
