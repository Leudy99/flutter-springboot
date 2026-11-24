package com.example.api.algorithmrace;

import com.example.api.algorithmrace.dto.AlgorithmRaceRequest;
import com.example.api.algorithmrace.dto.AlgorithmRaceResponse;
import com.example.api.algorithmrace.dto.AlgorithmResultDto;
import com.example.api.algorithmrace.service.AlgorithmRaceService;
import com.example.api.algorithmrace.service.InvalidRaceRequestException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Prueba aislada del modulo: sin Spring, sin base de datos. */
class AlgorithmRaceServiceTest {

    private final AlgorithmRaceService service = new AlgorithmRaceService(60);

    @Test
    void runsFiveAlgorithmsInParallelAndAllResultsAreCorrect() {
        AlgorithmRaceResponse response = service.run(new AlgorithmRaceRequest(5_000, 1234));

        assertEquals(5, response.results().size());
        for (AlgorithmResultDto r : response.results()) {
            assertTrue(r.success(), r.algorithm() + " devolvio un resultado incorrecto");
            assertTrue(r.durationNanoseconds() > 0);
        }
        assertEquals(5, response.ranking().size());
        assertEquals(3, response.sortRanking().size());
        assertEquals(2, response.searchRanking().size());
        assertNotNull(response.winner());
        // Cada algoritmo corrio en un hilo distinto
        long threads = response.results().stream().map(AlgorithmResultDto::threadName).distinct().count();
        assertEquals(5, threads);
    }

    @Test
    void handlesTargetThatDoesNotExist() {
        AlgorithmRaceResponse response = service.run(new AlgorithmRaceRequest(1_000, -7));
        response.results().forEach(r -> assertTrue(r.success()));
        response.results().stream().filter(r -> r.category().equals("SEARCH"))
                .forEach(r -> assertEquals(false, r.found()));
    }

    @Test
    void rejectsSizeBelowOne() {
        assertThrows(InvalidRaceRequestException.class,
                () -> service.run(new AlgorithmRaceRequest(0, 5)));
    }

    @Test
    void rejectsSizeThatDoesNotFitInMemory() {
        assertThrows(InvalidRaceRequestException.class,
                () -> service.run(new AlgorithmRaceRequest(Integer.MAX_VALUE, 5)));
    }

    @Test
    void slowAlgorithmsStopAtTheTimeLimitWithoutBlockingTheRace() {
        // Limite de 1 s: con 200,000 elementos Bubble e Insertion no terminan
        AlgorithmRaceResponse response =
                new AlgorithmRaceService(1).run(new AlgorithmRaceRequest(200_000, 7));

        AlgorithmResultDto bubble = response.results().get(0);
        assertEquals("Bubble Sort", bubble.algorithm());
        assertTrue(bubble.timedOut());
        assertEquals(false, bubble.success());
        // Los rapidos si terminan y siguen en el ranking
        assertEquals("Quick Sort", response.sortWinner());
        assertEquals(1, response.timeLimitSeconds());
    }

    @Test
    void acceptsAnySizeInsideTheRange() {
        AlgorithmRaceResponse response = service.run(new AlgorithmRaceRequest(777, 5));
        assertEquals(777, response.arraySize());
        response.results().forEach(r -> assertTrue(r.success()));
    }
}
