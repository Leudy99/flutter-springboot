#!/usr/bin/env python3
"""
Driver de las pruebas de carga.

K6 (los scripts .js) genera la carga. Este archivo la orquesta y mide lo que K6 no ve:
  - la cola SQS (mensajes visibles / en proceso, cada pocos segundos) -> results/*-queue.csv
  - cuanto tarda la cola en vaciarse al terminar la carga            -> results/*-drain.json
  - los criterios de parada de la prueba de estres
  - las metricas de AWS (CloudWatch) de una ventana de tiempo        -> comando "metrics"

Requisitos: AWS CLI configurado y Docker (usa la imagen grafana/k6) o K6 instalado.
Variables de entorno: K6_EMAIL y K6_PASSWORD (usuario de pruebas; nunca se guardan en el repo).

Ejemplos:
  python run.py baseline --name baseline-como-desplegado
  python run.py progressive --levels 50 100 250 500
  python run.py stress --levels 100 250 500 750 1000 1500 2000
  python run.py recovery --vus 250
  python run.py metrics --name recovery-250vu --start 2026-10-18T15:00:00Z --end 2026-10-18T15:10:00Z
"""
import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
REGION = os.environ.get("AWS_REGION", "us-east-2")
PROJECT = "flutter-springboot"
QUEUE_NAME = f"{PROJECT}-notification-queue"
DLQ_NAME = f"{QUEUE_NAME}-dlq"
TOPIC_NAME = f"{PROJECT}-notification-topic"
API_FUNCTION = f"{PROJECT}-api"
NOTIFICATION_FUNCTION = f"{PROJECT}-notification-lambda"

# Criterios de parada de la prueba de estres (actividad 4)
MAX_ERROR_RATE = 0.05        # mas de 5 % de errores
MAX_P95_MS = 5000            # latencia superior a 5 segundos
MAX_THROTTLED_SHARE = 0.01   # mas de 1 % de respuestas 429 = throttling
DRAIN_TIMEOUT_S = 180        # si la cola no se vacia en 3 min: saturacion de SQS


# ---------------------------------------------------------------- AWS CLI
def aws_cli():
    found = shutil.which("aws")
    if found:
        return found
    default = r"C:\Program Files\Amazon\AWSCLIV2\aws.exe"
    return default if os.path.exists(default) else "aws"


def aws(*args):
    """Ejecuta un comando de AWS CLI y devuelve su salida JSON (o None si falla)."""
    cmd = [aws_cli(), *args, "--region", REGION, "--output", "json"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    return json.loads(proc.stdout) if proc.stdout.strip() else {}


def queue_url(name):
    data = aws("sqs", "get-queue-url", "--queue-name", name)
    if not data:
        sys.exit(f"No se pudo obtener la cola {name}. Revisa AWS CLI y la region.")
    return data["QueueUrl"]


def queue_counts(url):
    """(mensajes visibles, mensajes en proceso) de una cola."""
    data = aws("sqs", "get-queue-attributes", "--queue-url", url, "--attribute-names",
               "ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible")
    if not data:
        return None
    attrs = data["Attributes"]
    return int(attrs["ApproximateNumberOfMessages"]), int(attrs["ApproximateNumberOfMessagesNotVisible"])


# ---------------------------------------------------------------- muestreo de la cola
class QueueSampler(threading.Thread):
    """Anota cada `interval` segundos cuantos mensajes hay en la cola y en la DLQ."""

    def __init__(self, interval=5):
        super().__init__(daemon=True)
        self.interval = interval
        self.queue = queue_url(QUEUE_NAME)
        self.dlq = queue_url(DLQ_NAME)
        self.rows = []
        self._halt = threading.Event()

    def run(self):
        while not self._halt.is_set():
            q, d = queue_counts(self.queue), queue_counts(self.dlq)
            if q and d:
                self.rows.append({
                    "time_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                    "visible": q[0], "in_flight": q[1], "dlq": d[0] + d[1],
                })
            self._halt.wait(self.interval)

    def stop(self):
        self._halt.set()
        self.join(timeout=15)

    def save(self, name):
        RESULTS.mkdir(exist_ok=True)
        with open(RESULTS / f"{name}-queue.csv", "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["time_utc", "visible", "in_flight", "dlq"])
            writer.writeheader()
            writer.writerows(self.rows)

    def peak(self, key):
        return max((r[key] for r in self.rows), default=0)


# ---------------------------------------------------------------- K6
def k6_command(script, env):
    """K6 local si existe; si no, la imagen oficial de Docker (sin instalar nada)."""
    pairs = []
    for key, value in env.items():
        pairs += ["-e", f"{key}={value}"]
    if shutil.which("k6"):
        return ["k6", "run", "--quiet", *pairs, script]
    return ["docker", "run", "--rm", "-i", "-v", f"{HERE}:/scripts", "-w", "/scripts",
            "grafana/k6:latest", "run", "--quiet", *pairs, script]


def run_k6(script, env, name):
    """Lanza K6 y devuelve (codigo de salida, resultado JSON del escenario)."""
    for required in ("K6_EMAIL", "K6_PASSWORD"):
        if not os.environ.get(required):
            sys.exit(f"Falta la variable de entorno {required}.")
    env = {**env, "K6_EMAIL": os.environ["K6_EMAIL"], "K6_PASSWORD": os.environ["K6_PASSWORD"],
           "RESULT_NAME": name}
    RESULTS.mkdir(exist_ok=True)
    result_file = RESULTS / f"{name}.json"
    result_file.unlink(missing_ok=True)

    code = subprocess.run(k6_command(script, env), cwd=HERE).returncode
    result = json.loads(result_file.read_text()) if result_file.exists() else None
    return code, result


# ---------------------------------------------------------------- escenario completo
def run_scenario(name, script, env, drain_timeout=DRAIN_TIMEOUT_S):
    """K6 + muestreo de la cola + tiempo de vaciado. Guarda y devuelve el resultado."""
    print(f"\n##### {name} #####", flush=True)
    sampler = QueueSampler()
    sampler.start()
    code, result = run_k6(script, env, name)
    if result is None:
        sampler.stop()
        sys.exit(f"K6 no genero resultados (codigo {code}). Revisa el login y la red.")

    # Tiempo que tarda la cola en vaciarse DESPUES de que K6 termino
    t0 = time.time()
    drained, empty_checks = None, 0
    while time.time() - t0 < drain_timeout:
        counts = queue_counts(sampler.queue)
        if counts is not None:
            empty_checks = empty_checks + 1 if counts == (0, 0) else 0
            if empty_checks >= 2:  # vacia en dos lecturas seguidas
                drained = round(time.time() - t0 - 5)  # -5: la lectura de confirmacion
                break
        time.sleep(5)
    sampler.stop()
    sampler.save(name)

    result["scenario"] = name
    result["k6ExitCode"] = code
    result["queue"] = {
        "peakVisible": sampler.peak("visible"),
        "peakInFlight": sampler.peak("in_flight"),
        "dlqAtEnd": sampler.rows[-1]["dlq"] if sampler.rows else None,
        "secondsToDrainAfterLoad": max(drained, 0) if drained is not None else None,
        "drainTimeoutSeconds": drain_timeout,
    }
    (RESULTS / f"{name}.json").write_text(json.dumps(result, indent=2))
    print(f"cola: pico visibles {result['queue']['peakVisible']}, en proceso {result['queue']['peakInFlight']}, "
          f"DLQ {result['queue']['dlqAtEnd']}, vaciada en {result['queue']['secondsToDrainAfterLoad']} s", flush=True)
    return result


# ---------------------------------------------------------------- comandos
def cmd_baseline(args):
    run_scenario(args.name, "baseline.js", {})


def cmd_progressive(args):
    for vus in args.levels:
        run_scenario(f"progressive-{vus}vu{args.suffix}", "progressive.js", {"VUS": vus, "DURATION": args.duration})


def stop_reason(r, total_requests, max_requests):
    """Devuelve el motivo para detener el estres, o None si el nivel fue aceptable."""
    if r["errorRate"] > MAX_ERROR_RATE:
        return f"mas de 5 % de errores ({r['errorRate'] * 100:.1f} %)"
    if r["latencyMs"]["p95"] > MAX_P95_MS:
        return f"latencia P95 superior a 5 s ({r['latencyMs']['p95']} ms)"
    if r["requests"] and r["status"]["throttled429"] / r["requests"] > MAX_THROTTLED_SHARE:
        return "throttling: mas de 1 % de respuestas 429"
    if r["queue"]["dlqAtEnd"]:
        return f"mensajes en la DLQ ({r['queue']['dlqAtEnd']})"
    if r["queue"]["secondsToDrainAfterLoad"] is None:
        return f"saturacion de SQS: la cola no se vacio en {DRAIN_TIMEOUT_S} s"
    if r["thresholdsFailed"] or r["k6ExitCode"] not in (0,):
        return "K6 aborto por umbral"
    if total_requests >= max_requests:
        return f"presupuesto de peticiones agotado ({max_requests})"
    return None


def cmd_stress(args):
    summary, total, reason = [], 0, None
    for vus in args.levels:
        r = run_scenario(f"stress-{vus}vu", "stress.js", {"VUS": vus, "DURATION": args.duration})
        total += r["requests"]
        reason = stop_reason(r, total, args.max_requests)
        summary.append({"vus": vus, "acceptable": reason is None, "stopReason": reason,
                        "errorRate": r["errorRate"], "p95": r["latencyMs"]["p95"],
                        "throughputRps": r["throughputRps"]})
        if reason:
            print(f"\n>>> DETENIDA en {vus} VU: {reason}", flush=True)
            break
    ok = [s["vus"] for s in summary if s["acceptable"]]
    out = {"levelsRun": summary, "totalRequests": total, "stopReason": reason,
           "maxAcceptableVus": max(ok) if ok else None}
    (RESULTS / "stress-summary.json").write_text(json.dumps(out, indent=2))
    print(json.dumps(out, indent=2))


def cmd_recovery(args):
    run_scenario(f"recovery-{args.vus}vu", "recovery.js", {"VUS": args.vus, "DURATION": args.duration},
                 drain_timeout=args.drain_timeout)


def cmd_metrics(args):
    """Descarga de CloudWatch las metricas pedidas por la actividad para una ventana de tiempo."""
    api = aws("apigatewayv2", "get-apis", "--query", f"Items[?contains(Name,'{PROJECT}')].ApiId")
    api_id = api[0] if api else None
    start, end = args.start, args.end
    specs = [  # (namespace, metrica, dimension, estadistica)
        ("AWS/ApiGateway", "Count", f"ApiId={api_id}", "Sum"),
        ("AWS/ApiGateway", "Latency", f"ApiId={api_id}", "Average"),
        ("AWS/ApiGateway", "IntegrationLatency", f"ApiId={api_id}", "Average"),
        ("AWS/ApiGateway", "4xx", f"ApiId={api_id}", "Sum"),
        ("AWS/ApiGateway", "5xx", f"ApiId={api_id}", "Sum"),
        ("AWS/Lambda", "Invocations", f"FunctionName={API_FUNCTION}", "Sum"),
        ("AWS/Lambda", "Duration", f"FunctionName={API_FUNCTION}", "Average"),
        ("AWS/Lambda", "Errors", f"FunctionName={API_FUNCTION}", "Sum"),
        ("AWS/Lambda", "Throttles", f"FunctionName={API_FUNCTION}", "Sum"),
        ("AWS/Lambda", "ConcurrentExecutions", f"FunctionName={API_FUNCTION}", "Maximum"),
        ("AWS/SNS", "NumberOfMessagesPublished", f"TopicName={TOPIC_NAME}", "Sum"),
        ("AWS/SQS", "NumberOfMessagesSent", f"QueueName={QUEUE_NAME}", "Sum"),
        ("AWS/SQS", "ApproximateNumberOfMessagesVisible", f"QueueName={QUEUE_NAME}", "Maximum"),
        ("AWS/Lambda", "Invocations", f"FunctionName={NOTIFICATION_FUNCTION}", "Sum"),
        ("AWS/Lambda", "Duration", f"FunctionName={NOTIFICATION_FUNCTION}", "Average"),
        ("AWS/Lambda", "Errors", f"FunctionName={NOTIFICATION_FUNCTION}", "Sum"),
        ("AWS/Lambda", "Throttles", f"FunctionName={NOTIFICATION_FUNCTION}", "Sum"),
        ("AWS/Lambda", "ConcurrentExecutions", f"FunctionName={NOTIFICATION_FUNCTION}", "Maximum"),
    ]
    rows = []
    for namespace, metric, dimension, stat in specs:
        data = aws("cloudwatch", "get-metric-statistics", "--namespace", namespace, "--metric-name", metric,
                   "--dimensions", f"Name={dimension.split('=')[0]},Value={dimension.split('=')[1]}",
                   "--start-time", start, "--end-time", end, "--period", "60", "--statistics", stat)
        if data is None:
            sys.exit("Sin permiso para leer CloudWatch (cloudwatch:GetMetricStatistics). "
                     "Agrega CloudWatchReadOnlyAccess al usuario o usa las capturas de la consola.")
        for point in data["Datapoints"]:
            rows.append({"namespace": namespace, "metric": metric, "dimension": dimension,
                         "stat": stat, "time_utc": point["Timestamp"], "value": point[stat]})
    rows.sort(key=lambda r: (r["namespace"], r["metric"], r["dimension"], r["time_utc"]))
    RESULTS.mkdir(exist_ok=True)
    out = RESULTS / f"aws-metrics-{args.name}.csv"
    with open(out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["namespace", "metric", "dimension", "stat", "time_utc", "value"])
        writer.writeheader()
        writer.writerows(rows)
    print(f"{len(rows)} puntos guardados en {out}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("baseline"); p.add_argument("--name", default="baseline"); p.set_defaults(fn=cmd_baseline)
    p = sub.add_parser("progressive"); p.add_argument("--levels", type=int, nargs="+", default=[50, 100, 250, 500])
    p.add_argument("--duration", default="2m")
    p.add_argument("--suffix", default="", help="sufijo del nombre, ej. -como-desplegado"); p.set_defaults(fn=cmd_progressive)
    p = sub.add_parser("stress"); p.add_argument("--levels", type=int, nargs="+", default=[100, 250, 500, 750, 1000, 1500, 2000])
    p.add_argument("--duration", default="1m"); p.add_argument("--max-requests", type=int, default=250000)
    p.set_defaults(fn=cmd_stress)
    p = sub.add_parser("recovery"); p.add_argument("--vus", type=int, default=250); p.add_argument("--duration", default="1m")
    p.add_argument("--drain-timeout", type=int, default=600); p.set_defaults(fn=cmd_recovery)
    p = sub.add_parser("metrics"); p.add_argument("--name", required=True)
    p.add_argument("--start", required=True); p.add_argument("--end", required=True); p.set_defaults(fn=cmd_metrics)

    args = parser.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
