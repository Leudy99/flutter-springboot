package com.example.api.algorithmrace.dto;

/** Una fila de un ranking de velocidad (position 1 = mas rapido). */
public record RankingEntryDto(
        int position,
        String algorithm,
        String category,
        double durationMilliseconds,
        long durationNanoseconds
) {
}
