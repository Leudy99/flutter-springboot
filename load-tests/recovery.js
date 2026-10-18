// PRUEBA DE RECUPERACION: una carga alta durante un rato y despues se detiene por completo.
// K6 solo genera la carga; run.py mide despues cuanto tarda SQS en vaciarse y las Lambdas
// en volver a la normalidad. No tiene umbrales de aborto: la idea es llegar al pico.
//
//   k6 run -e VUS=250 -e K6_EMAIL=... -e K6_PASSWORD=... recovery.js
import { setupToken, sendNotification, buildSummary, thresholds, TREND_STATS } from './config.js';

const VUS = Number(__ENV.VUS || 250);
const DURATION = __ENV.DURATION || '1m';

export const options = {
  vus: VUS,
  duration: DURATION,
  summaryTrendStats: TREND_STATS,
  thresholds: thresholds(),
};

export function setup() {
  return setupToken();
}

export default function (data) {
  sendNotification(data.token);
}

export function handleSummary(data) {
  return buildSummary(`recovery-${VUS}vu`, data, VUS, DURATION);
}
