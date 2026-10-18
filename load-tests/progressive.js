// INCREMENTO PROGRESIVO: se ejecuta una vez por nivel de carga (50, 100, 250 y 500 usuarios, 2 min).
// Cada nivel se lanza por separado para que empiece con la cola vacia y cada resultado
// se guarde en su propio archivo.
//
//   k6 run -e VUS=50 -e K6_EMAIL=... -e K6_PASSWORD=... progressive.js
import { setupToken, sendNotification, buildSummary, thresholds, TREND_STATS } from './config.js';

const VUS = Number(__ENV.VUS || 50);
const DURATION = __ENV.DURATION || '2m';

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
  return buildSummary(`progressive-${VUS}vu`, data, VUS, DURATION);
}
