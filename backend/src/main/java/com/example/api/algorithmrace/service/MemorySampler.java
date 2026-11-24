package com.example.api.algorithmrace.service;

/**
 * Hilo auxiliar que mide la memoria usada de la JVM mientras corre un algoritmo
 * y se queda con el valor maximo ("memoria durante la ejecucion").
 *
 * IMPORTANTE: la heap de la JVM es compartida por todos los hilos, asi que
 * esta cifra es APROXIMADA: incluye lo que hacen los otros algoritmos y el
 * Garbage Collector al mismo tiempo.
 */
class MemorySampler extends Thread {

    private volatile boolean running = true;
    private volatile long peakBytes;

    MemorySampler(long initialBytes) {
        super("memory-sampler");
        setDaemon(true);
        this.peakBytes = initialBytes;
    }

    static long usedMemory() {
        Runtime runtime = Runtime.getRuntime();
        return runtime.totalMemory() - runtime.freeMemory();
    }

    @Override
    public void run() {
        while (running) {
            peakBytes = Math.max(peakBytes, usedMemory());
            try {
                Thread.sleep(1);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    /** Detiene el muestreo y devuelve el maximo observado. */
    long stopAndGetPeak() {
        running = false;
        interrupt();
        return Math.max(peakBytes, usedMemory());
    }
}
