// PRUEBA DE ESTRES: un nivel de carga por ejecucion (20, 30, 40, 50, 100, 250, ... usuarios).
// run.py lanza los niveles en orden y decide si seguir.
//
// Cada nivel tiene dos fases:
//   - "ramp": los usuarios van entrando gradualmente (20 s). Asi no se mide el golpe de que
//             todos disparen a la vez en el segundo 0, cuando Lambda aun debe crear instancias.
//   - "hold": todos los usuarios activos de forma sostenida (60 s). SOLO esta fase cuenta
//             para los umbrales y para los resultados.
//
// Criterios de parada de la actividad que K6 vigila por si mismo (abortOnFail, fase hold):
//   - mas de 5 % de errores
//   - latencia P95 superior a 5 segundos
// El driver revisa ademas la cola SQS y el throttling de las Lambdas.
//
//   k6 run -e VUS=500 -e K6_EMAIL=... -e K6_PASSWORD=... stress.js
import exec from 'k6/execution';
import { setupToken, sendNotification, buildSummary, thresholds, TREND_STATS } from './config.js';

const VUS = Number(__ENV.VUS || 100);
const RAMP_SECONDS = Number(__ENV.RAMP_SECONDS || 20);
const HOLD_SECONDS = Number(__ENV.HOLD_SECONDS || 60);

export const options = {
  scenarios: {
    estres: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: `${RAMP_SECONDS}s`, target: VUS },
        { duration: `${HOLD_SECONDS}s`, target: VUS },
      ],
      gracefulRampDown: '0s',
    },
  },
  summaryTrendStats: TREND_STATS,
  thresholds: thresholds(true, 'hold'), // aborta con >5 % de errores o P95 > 5 s en la fase sostenida
};

export function setup() {
  return setupToken();
}

export default function (data) {
  const elapsedMs = exec.instance.currentTestRunDuration;
  sendNotification(data.token, elapsedMs >= RAMP_SECONDS * 1000 ? 'hold' : 'ramp');
}

export function handleSummary(data) {
  return buildSummary(`stress-${VUS}vu`, data, VUS, `${RAMP_SECONDS}s rampa + ${HOLD_SECONDS}s sostenido`, 'hold');
}
