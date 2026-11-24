package com.example.api.algorithmrace.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/** Resultado de un algoritmo, tal como se envia a Flutter. */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record AlgorithmResultDto(
        String algorithm,
        String category,
        String startTime,
        String endTime,
        double durationMilliseconds,
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
}
