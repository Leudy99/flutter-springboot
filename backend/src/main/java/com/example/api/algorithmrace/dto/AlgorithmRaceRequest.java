package com.example.api.algorithmrace.dto;

import jakarta.validation.constraints.NotNull;

/** Cuerpo de POST /api/algorithm-race/run. */
public record AlgorithmRaceRequest(
        @NotNull(message = "El tamano del arreglo es obligatorio")
        Integer arraySize,

        @NotNull(message = "El numero buscado es obligatorio")
        Integer target
) {
}
