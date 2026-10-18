// PRUEBA DE ESTRES: un nivel de carga por ejecucion (100, 250, 500, 750, 1000, 1500, 2000 usuarios).
// run.py lanza los niveles en orden y decide si seguir.
//
// Criterios de parada de la actividad que K6 vigila por si mismo (abortOnFail):
//   - mas de 5 % de errores
//   - latencia P95 superior a 5 segundos
// El driver revisa ademas la cola SQS y el throttling de las Lambdas.
//
//   k6 run -e VUS=500 -e K6_EMAIL=... -e K6_PASSWORD=... stress.js
import { setupToken, sendNotification, buildSummary, thresholds, TREND_STATS } from './config.js';

const VUS = Number(__ENV.VUS || 100);
const DURATION = __ENV.DURATION || '1m';

export const options = {
  vus: VUS,
  duration: DURATION,
  summaryTrendStats: TREND_STATS,
  thresholds: thresholds(true), // aborta con >5 % de errores o P95 > 5 s
};

export function setup() {
  return setupToken();
}

export default function (data) {
  sendNotification(data.token);
}

export function handleSummary(data) {
  return buildSummary(`stress-${VUS}vu`, data, VUS, DURATION);
}
