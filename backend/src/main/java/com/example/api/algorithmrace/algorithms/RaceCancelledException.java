package com.example.api.algorithmrace.algorithms;

/** Se lanza cuando la carrera interrumpe un algoritmo que superó el tiempo límite. */
public class RaceCancelledException extends RuntimeException {

    public RaceCancelledException() {
        super("Algoritmo cancelado por tiempo límite", null, false, false);
    }

    /** Llamar en el bucle externo: si el hilo fue interrumpido, termina el algoritmo. */
    public static void checkInterrupted() {
        if (Thread.currentThread().isInterrupted()) {
            throw new RaceCancelledException();
        }
    }
}
