// Configuracion y funciones comunes de todas las pruebas de carga (K6).
//
// Endpoint bajo prueba:  POST /notifications/send
// Flujo evaluado:        API Gateway -> Lambda principal -> SNS -> SQS -> notification-lambda
//
// Nada sensible esta escrito aqui: el usuario y la contrasena llegan por variables de
// entorno (K6_EMAIL y K6_PASSWORD) y la URL de API Gateway se puede cambiar con BASE_URL.
import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { Counter } from 'k6/metrics';

// URL publica de API Gateway (output "api_url" de Terraform). No es un secreto.
export const BASE_URL =
  __ENV.BASE_URL || 'https://k3gjsmho82.execute-api.us-east-2.amazonaws.com';

// Pausa entre peticiones de cada usuario virtual: un usuario envia ~1 mensaje por segundo.
export const THINK_TIME = Number(__ENV.THINK_TIME || 1);

// Destinatario de prueba. El dominio test.com activa el "modo de carga" de
// notification-lambda: el mensaje se recibe y procesa, pero NO se envia correo real.
const TARGET_EMAIL = __ENV.TARGET_EMAIL || 'test@test.com';

// Solo se mide ESTA peticion; el login de setup() queda fuera de los resultados.
const ENDPOINT = 'POST /notifications/send';
const M = (metric) => `${metric}{name:${ENDPOINT}}`;

/**
 * Umbrales de K6. Los vacios solo sirven para que K6 calcule y muestre las metricas
 * de la peticion medida por separado. Con `abort` el estres se detiene solo al superar
 * los limites de la actividad (5 % de errores o P95 mayor a 5 s).
 */
export function thresholds(abort = false) {
  const stop = (threshold) => (abort ? [{ threshold, abortOnFail: true, delayAbortEval: '10s' }] : []);
  return {
    [M('http_req_duration')]: stop('p(95)<5000'),
    [M('http_req_failed')]: stop('rate<0.05'),
    [M('http_reqs')]: [],
  };
}

// Estadisticos que se guardan de cada metrica de tiempo.
export const TREND_STATS = ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'];

// Contadores por codigo de respuesta (para distinguir 429 / 5xx del resto de errores).
const status200 = new Counter('status_200');
const status429 = new Counter('status_429');
const status5xx = new Counter('status_5xx');
const statusOtro = new Counter('status_otro');

/** Inicia sesion UNA vez (en setup) y devuelve el JWT que usan todos los usuarios virtuales. */
export function setupToken() {
  const email = __ENV.K6_EMAIL;
  const password = __ENV.K6_PASSWORD;
  if (!email || !password) {
    fail('Faltan las variables de entorno K6_EMAIL y K6_PASSWORD (usuario de pruebas).');
  }
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email, password }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '60s' }
  );
  if (res.status !== 200) {
    fail(`Login fallido (${res.status}): no se puede ejecutar la prueba.`);
  }
  return { token: res.json('token') };
}

/** Una iteracion de un usuario virtual: envia una notificacion y espera THINK_TIME. */
export function sendNotification(token) {
  const res = http.post(
    `${BASE_URL}/notifications/send`,
    JSON.stringify({ email: TARGET_EMAIL, subject: 'Prueba', message: 'Mensaje de carga' }),
    {
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      tags: { name: ENDPOINT },
      timeout: '30s',
    }
  );

  check(res, { 'status 200': (r) => r.status === 200 });

  if (res.status === 200) status200.add(1);
  else if (res.status === 429) status429.add(1);
  else if (res.status >= 500) status5xx.add(1);
  else statusOtro.add(1); // incluye status 0 (timeout o conexion rechazada)

  sleep(THINK_TIME);
}

/**
 * Resumen de la ejecucion: se imprime en consola y se guarda en results/<nombre>.json
 * para poder comparar escenarios y construir las graficas del informe.
 */
export function buildSummary(scenario, data, vus, duration) {
  const m = data.metrics;
  // Metricas de POST /notifications/send (sin el login de setup)
  const v = (name, key) => {
    const metric = m[M(name)] || m[name];
    return metric && metric.values[key] !== undefined ? metric.values[key] : 0;
  };
  // Los contadores de estado no llevan etiqueta
  const c = (name) => (m[name] ? m[name].values.count : 0);

  const end = new Date();
  const start = new Date(end.getTime() - data.state.testRunDurationMs);

  const result = {
    scenario,
    vus,
    duration,
    startedAt: start.toISOString(),
    endedAt: end.toISOString(),
    testRunSeconds: Math.round(data.state.testRunDurationMs / 1000),
    requests: v('http_reqs', 'count'),
    throughputRps: Number(v('http_reqs', 'rate').toFixed(2)),
    errorRate: Number(v('http_req_failed', 'rate').toFixed(4)),
    latencyMs: {
      avg: Number(v('http_req_duration', 'avg').toFixed(1)),
      min: Number(v('http_req_duration', 'min').toFixed(1)),
      med: Number(v('http_req_duration', 'med').toFixed(1)),
      p90: Number(v('http_req_duration', 'p(90)').toFixed(1)),
      p95: Number(v('http_req_duration', 'p(95)').toFixed(1)),
      p99: Number(v('http_req_duration', 'p(99)').toFixed(1)),
      max: Number(v('http_req_duration', 'max').toFixed(1)),
    },
    status: {
      ok200: c('status_200'),
      throttled429: c('status_429'),
      errors5xx: c('status_5xx'),
      other: c('status_otro'),
    },
    thresholdsFailed: Object.keys(m).filter(
      (name) => m[name].thresholds && Object.values(m[name].thresholds).some((t) => t.ok === false)
    ),
  };

  const text =
    `\n=== ${scenario} | ${vus} VU | ${duration} ===\n` +
    `peticiones: ${result.requests}   throughput: ${result.throughputRps} req/s   errores: ${(result.errorRate * 100).toFixed(2)} %\n` +
    `latencia ms -> avg ${result.latencyMs.avg}  min ${result.latencyMs.min}  p95 ${result.latencyMs.p95}  p99 ${result.latencyMs.p99}  max ${result.latencyMs.max}\n` +
    `respuestas -> 200: ${result.status.ok200}  429: ${result.status.throttled429}  5xx: ${result.status.errors5xx}  otras: ${result.status.other}\n` +
    (result.thresholdsFailed.length ? `UMBRALES SUPERADOS: ${result.thresholdsFailed.join(', ')}\n` : '');

  const name = __ENV.RESULT_NAME || scenario;
  return {
    stdout: text,
    [`results/${name}.json`]: JSON.stringify(result, null, 2),
  };
}
