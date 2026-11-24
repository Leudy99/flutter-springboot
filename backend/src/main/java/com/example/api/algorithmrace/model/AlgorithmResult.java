package com.example.api.algorithmrace.model;

import java.time.LocalDateTime;

/**
 * Resultado interno de un algoritmo tras correr en su hilo.
 * "found" e "index" solo aplican a las busquedas (null en ordenamientos).
 */
public record AlgorithmResult(
        String algorithm,
        Category category,
        LocalDateTime startTime,
        LocalDateTime endTime,
        long durationNanoseconds,
        long memoryBeforeBytes,
        long memoryDuringBytes,
        long memoryAfterBytes,
        boolean success,
        boolean timedOut,
        Boolean found,
        Integer index,
        String threadName
) {

    public enum Category { SORT, SEARCH }

    public double durationMilliseconds() {
        return durationNanoseconds / 1_000_000.0;
    }
}
