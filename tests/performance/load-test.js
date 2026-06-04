import http from 'k6/http';
import { check, sleep } from 'k6';

// URL cible — surchargeable via la variable d'environnement BASE_URL
// (ex: k6 run -e BASE_URL=http://localhost:8080 load-test.js)
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // Montée en charge progressive
  stages: [
    { duration: '15s', target: 10 },  // montée à 10 utilisateurs virtuels
    { duration: '30s', target: 10 },  // palier à 10 VUs
    { duration: '15s', target: 0 },   // descente à 0
  ],
  // Seuils de validation (le test échoue si non respectés)
  thresholds: {
    http_req_duration: ['p(95)<500'],   // 95% des requêtes sous 500 ms
    http_req_failed: ['rate<0.01'],     // moins de 1% d'échecs HTTP
  },
};

export default function () {
  const res = http.get(BASE_URL);

  // Vérification : le serveur répond bien avec un statut HTTP 200
  check(res, {
    'statut 200': (r) => r.status === 200,
  });

  sleep(1);
}
