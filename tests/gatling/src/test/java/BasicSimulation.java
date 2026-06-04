import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;

/**
 * Test de performance simple de la page d'accueil servie par Nginx.
 * URL cible configurable via -DbaseUrl (défaut : http://localhost:8080).
 */
public class BasicSimulation extends Simulation {

  // Protocole HTTP : URL de base surchargeable par propriété système
  HttpProtocolBuilder httpProtocol =
      http.baseUrl(System.getProperty("baseUrl", "http://localhost:8080"))
          .acceptHeader("text/html,application/xhtml+xml")
          .userAgentHeader("Gatling/PerfTest");

  // Scénario : un GET sur la racine, on vérifie le statut 200
  ScenarioBuilder scn =
      scenario("Page d'accueil")
          .exec(http("GET /").get("/").check(status().is(200)));

  // Profil de charge + seuils de validation (le test échoue si non respectés)
  {
    setUp(
            scn.injectOpen(
                rampUsersPerSec(1).to(10).during(15), // montée : 1 -> 10 req/s sur 15s
                constantUsersPerSec(10).during(30)     // palier : 10 req/s pendant 30s
            ))
        .protocols(httpProtocol)
        .assertions(
            global().responseTime().percentile(95).lt(500), // p95 < 500 ms
            global().failedRequests().percent().lt(1.0)      // < 1% d'échecs
        );
  }
}
