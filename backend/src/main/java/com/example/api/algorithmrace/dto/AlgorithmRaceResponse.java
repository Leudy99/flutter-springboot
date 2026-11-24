package com.example.api.algorithmrace.dto;

import java.util.List;

/** Respuesta completa de la carrera. Todo se calcula en memoria, nada se guarda. */
public record AlgorithmRaceResponse(
        int arraySize,
        int target,
        int availableProcessors,
        int timeLimitSeconds,
        double totalRaceMilliseconds,
        List<AlgorithmResultDto> results,
        String winner,
        String sortWinner,
        String searchWinner,
        List<RankingEntryDto> ranking,
        List<RankingEntryDto> sortRanking,
        List<RankingEntryDto> searchRanking
) {
}
