// LINEA BASE: 10 usuarios virtuales durante 1 minuto.
// Es la referencia con la que se comparan las cargas mayores.
//
//   k6 run -e K6_EMAIL=... -e K6_PASSWORD=... baseline.js
import { setupToken, sendNotification, buildSummary, thresholds, TREND_STATS } from './config.js';

export const options = {
  vus: 10,
  duration: '1m',
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
  return buildSummary('baseline', data, 10, '1m');
}
