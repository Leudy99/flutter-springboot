#!/usr/bin/env python3
"""
Genera las graficas del informe a partir de los resultados REALES guardados en results/.
No inventa ni interpola datos: cada punto sale de un archivo JSON/CSV de una ejecucion.

  python plot.py          ->  results/charts/*.png
Requiere: matplotlib
"""
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
CHARTS = RESULTS / "charts"

TEAL, INK, AMBER, RED = "#0F766E", "#1E2A3B", "#B45309", "#B42318"


def load(name):
    path = RESULTS / f"{name}.json"
    return json.loads(path.read_text()) if path.exists() else None


def series(prefix, extra=()):
    """Resultados de un grupo de escenarios ordenados por usuarios virtuales."""
    rows = []
    for path in RESULTS.glob(f"{prefix}-*vu.json"):
        data = json.loads(path.read_text())
        rows.append(data)
    for name in extra:
        data = load(name)
        if data:
            rows.append(data)
    return sorted(rows, key=lambda r: r["vus"])


def style(ax, title, xlabel, ylabel):
    ax.set_title(title, fontsize=12, fontweight="bold", color=INK)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.grid(True, alpha=0.3)
    ax.spines[["top", "right"]].set_visible(False)


def save(fig, name):
    CHARTS.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(CHARTS / name, dpi=140)
    plt.close(fig)
    print("grafica:", CHARTS / name)


def load_charts(rows, prefix, label):
    if len(rows) < 2:
        return
    users = [r["vus"] for r in rows]

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(users, [r["latencyMs"]["avg"] for r in rows], "o-", color=TEAL, label="Promedio")
    ax.plot(users, [r["latencyMs"]["p95"] for r in rows], "s-", color=AMBER, label="P95")
    ax.plot(users, [r["latencyMs"]["p99"] for r in rows], "^-", color=RED, label="P99")
    style(ax, f"Latencia vs usuarios ({label})", "Usuarios virtuales", "Latencia (ms)")
    ax.legend()
    save(fig, f"{prefix}-latencia.png")

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(users, [r["throughputRps"] for r in rows], "o-", color=TEAL, label="Todas las respuestas")
    ax.plot(users, [r["status"]["ok200"] / max(r["testRunSeconds"], 1) for r in rows], "s--", color=INK,
            label="Solo respuestas 200")
    style(ax, f"Throughput vs usuarios ({label})", "Usuarios virtuales", "Peticiones por segundo")
    ax.legend()
    save(fig, f"{prefix}-throughput.png")

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar([str(u) for u in users], [r["errorRate"] * 100 for r in rows], color=RED)
    ax.axhline(5, color=INK, linestyle="--", linewidth=1, label="Limite de la actividad (5 %)")
    style(ax, f"Errores vs usuarios ({label})", "Usuarios virtuales", "Tasa de errores (%)")
    ax.legend()
    save(fig, f"{prefix}-errores.png")


def queue_chart(name, title):
    path = RESULTS / f"{name}-queue.csv"
    if not path.exists():
        return
    with open(path) as f:
        rows = list(csv.DictReader(f))
    if len(rows) < 3:
        return
    from datetime import datetime

    t0 = datetime.fromisoformat(rows[0]["time_utc"])
    seconds = [(datetime.fromisoformat(r["time_utc"]) - t0).total_seconds() for r in rows]
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(seconds, [int(r["visible"]) for r in rows], "-", color=TEAL, label="Visibles en la cola")
    ax.plot(seconds, [int(r["in_flight"]) for r in rows], "-", color=AMBER, label="En proceso")
    ax.plot(seconds, [int(r["dlq"]) for r in rows], "-", color=RED, label="En la DLQ")
    style(ax, title, "Segundos desde el inicio de la prueba", "Mensajes")
    ax.legend()
    save(fig, f"{name}-cola.png")


def main():
    # Incremento progresivo: 10 (linea base con limite alto) + 50 + 100 + 250 + 500
    progressive = series("progressive", extra=("baseline-limite-alto",))
    progressive = [r for r in progressive if "como-desplegado" not in r["scenario"]]
    load_charts(progressive, "progresivo", "incremento progresivo")

    stress = series("stress")
    load_charts(stress, "estres", "prueba de estres")

    for path in RESULTS.glob("*-queue.csv"):
        name = path.name[: -len("-queue.csv")]
        queue_chart(name, f"Cola SQS durante {name}")


if __name__ == "__main__":
    main()
