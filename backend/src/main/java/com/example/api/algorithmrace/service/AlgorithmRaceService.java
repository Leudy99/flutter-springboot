package com.example.api.algorithmrace.service;

import com.example.api.algorithmrace.algorithms.BinarySearchAlgorithm;
import com.example.api.algorithmrace.algorithms.BubbleSortAlgorithm;
import com.example.api.algorithmrace.algorithms.InsertionSortAlgorithm;
import com.example.api.algorithmrace.algorithms.QuickSortAlgorithm;
import com.example.api.algorithmrace.algorithms.RaceCancelledException;
import com.example.api.algorithmrace.algorithms.SequentialSearchAlgorithm;
import com.example.api.algorithmrace.dto.AlgorithmRaceRequest;
import com.example.api.algorithmrace.dto.AlgorithmRaceResponse;
import com.example.api.algorithmrace.dto.AlgorithmResultDto;
import com.example.api.algorithmrace.dto.RankingEntryDto;
import com.example.api.algorithmrace.model.AlgorithmResult;
import com.example.api.algorithmrace.model.AlgorithmResult.Category;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Random;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Carrera de algoritmos: ordena y busca sobre el MISMO arreglo, con los cinco
 * algoritmos corriendo a la vez (un hilo por algoritmo), y arma el ranking.
 *
 * El tamano del arreglo es libre. Para que un algoritmo O(n^2) no deje la
 * peticion trabajando horas, cada algoritmo tiene un tiempo limite: si lo
 * supera se interrumpe y se informa como "no termino".
 *
 * Todo ocurre en memoria: no usa base de datos ni guarda historial.
 */
@Service
public class AlgorithmRaceService {

    /** Arreglos vivos a la vez: original, 3 copias para ordenar y 1 ordenado. */
    private static final int ARRAYS_IN_MEMORY = 5;

    private final BubbleSortAlgorithm bubbleSort = new BubbleSortAlgorithm();
    private final InsertionSortAlgorithm insertionSort = new InsertionSortAlgorithm();
    private final QuickSortAlgorithm quickSort = new QuickSortAlgorithm();
    private final SequentialSearchAlgorithm sequentialSearch = new SequentialSearchAlgorithm();
    private final BinarySearchAlgorithm binarySearch = new BinarySearchAlgorithm();

    private final int timeLimitSeconds;

    public AlgorithmRaceService(
            @Value("${algorithm-race.time-limit-seconds:60}") int timeLimitSeconds) {
        this.timeLimitSeconds = timeLimitSeconds;
    }

    /** Lo que se mide: solo el algoritmo, sin copias ni validaciones. */
    @FunctionalInterface
    private interface TimedWork {
        Integer execute(); // indice (busquedas) o null (ordenamientos)
    }

    /** Validacion del resultado: se ejecuta FUERA del tiempo medido. */
    @FunctionalInterface
    private interface Verifier {
        boolean verify(Integer index);
    }

    /** Una tarea de la carrera: sus datos y el codigo que corre en su hilo. */
    private record RaceTask(String name, Category category, Callable<AlgorithmResult> call) {
    }

    public AlgorithmRaceResponse run(AlgorithmRaceRequest request) {
        validate(request);
        int size = request.arraySize();
        int target = request.target();

        // 1. Arreglo original: se genera UNA sola vez por ejecucion
        int[] original = generateArray(size);

        // 2. Copias independientes: cada ordenamiento trabaja sobre la suya
        int[] bubbleCopy = Arrays.copyOf(original, size);
        int[] insertionCopy = Arrays.copyOf(original, size);
        int[] quickCopy = Arrays.copyOf(original, size);

        // 3. Arreglo ordenado para Binary Search, preparado ANTES de medir.
        //    (Arrays.sort solo se usa aqui, como preparacion y como referencia
        //    para validar; los 3 ordenamientos de la carrera son manuales.)
        int[] sorted = Arrays.copyOf(original, size);
        Arrays.sort(sorted);
        boolean targetExists = Arrays.binarySearch(sorted, target) >= 0;

        // 4. Cinco tareas, una por algoritmo
        CountDownLatch startSignal = new CountDownLatch(1);
        List<RaceTask> tasks = List.of(
                task("Bubble Sort", Category.SORT, startSignal,
                        () -> { bubbleSort.sort(bubbleCopy); return null; },
                        index -> Arrays.equals(bubbleCopy, sorted)),
                task("Insertion Sort", Category.SORT, startSignal,
                        () -> { insertionSort.sort(insertionCopy); return null; },
                        index -> Arrays.equals(insertionCopy, sorted)),
                task("Quick Sort", Category.SORT, startSignal,
                        () -> { quickSort.sort(quickCopy); return null; },
                        index -> Arrays.equals(quickCopy, sorted)),
                task("Sequential Search", Category.SEARCH, startSignal,
                        () -> sequentialSearch.search(original, target),
                        index -> searchIsCorrect(original, target, index, targetExists)),
                task("Binary Search", Category.SEARCH, startSignal,
                        () -> binarySearch.search(sorted, target),
                        index -> searchIsCorrect(sorted, target, index, targetExists))
        );

        // 5. Ejecucion paralela: un hilo por tarea
        List<AlgorithmResult> results = runInParallel(tasks, startSignal);

        return buildResponse(size, target, results);
    }

    // ---------------------------------------------------------------- paralelo

    private List<AlgorithmResult> runInParallel(List<RaceTask> tasks, CountDownLatch startSignal) {
        AtomicInteger counter = new AtomicInteger(1);
        ExecutorService executor = Executors.newFixedThreadPool(tasks.size(), runnable -> {
            Thread thread = new Thread(runnable, "race-thread-" + counter.getAndIncrement());
            thread.setDaemon(true);
            return thread;
        });
        try {
            List<Future<AlgorithmResult>> futures = new ArrayList<>();
            for (RaceTask task : tasks) {
                futures.add(executor.submit(task.call()));
            }
            // Todos los hilos ya existen y esperan: se da la senal de salida a la vez
            LocalDateTime raceStart = LocalDateTime.now();
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(timeLimitSeconds);
            startSignal.countDown();

            // Esperar a que terminen los cinco (o a que se agote el tiempo limite)
            List<AlgorithmResult> results = new ArrayList<>();
            for (int i = 0; i < futures.size(); i++) {
                long remaining = Math.max(0, deadline - System.nanoTime());
                try {
                    results.add(futures.get(i).get(remaining, TimeUnit.NANOSECONDS));
                } catch (TimeoutException e) {
                    futures.get(i).cancel(true); // interrumpe el hilo del algoritmo
                    results.add(timedOutResult(tasks.get(i), raceStart));
                }
            }
            return results;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("La carrera fue interrumpida", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Fallo un algoritmo de la carrera", e.getCause());
        } finally {
            startSignal.countDown();
            executor.shutdownNow();
        }
    }

    /** Envuelve un algoritmo con la medicion de tiempo y memoria. */
    private RaceTask task(String name, Category category, CountDownLatch startSignal,
                          TimedWork work, Verifier verifier) {
        Callable<AlgorithmResult> call = () -> {
            startSignal.await(); // salida simultanea

            long memoryBefore = MemorySampler.usedMemory();
            MemorySampler sampler = new MemorySampler(memoryBefore);
            sampler.start();

            try {
                // ---- zona medida: solo el algoritmo ----
                LocalDateTime startTime = LocalDateTime.now();
                long startNs = System.nanoTime();
                Integer index = work.execute();
                long endNs = System.nanoTime();
                LocalDateTime endTime = LocalDateTime.now();
                // ----------------------------------------

                long memoryAfter = MemorySampler.usedMemory();
                long memoryDuring = sampler.stopAndGetPeak();

                boolean success = verifier.verify(index); // fuera del tiempo medido

                Boolean found = category == Category.SEARCH ? index != null && index >= 0 : null;
                Integer foundIndex = category == Category.SEARCH && index != null && index >= 0
                        ? index : null;

                return new AlgorithmResult(name, category, startTime, endTime,
                        endNs - startNs, memoryBefore, memoryDuring, memoryAfter,
                        success, false, found, foundIndex, Thread.currentThread().getName());
            } catch (RaceCancelledException e) {
                // Pasado el tiempo limite: el resultado ya lo arma timedOutResult()
                return null;
            } finally {
                sampler.stopAndGetPeak();
            }
        };
        return new RaceTask(name, category, call);
    }

    /** Resultado de un algoritmo que no termino dentro del tiempo limite. */
    private AlgorithmResult timedOutResult(RaceTask task, LocalDateTime raceStart) {
        long limitNs = TimeUnit.SECONDS.toNanos(timeLimitSeconds);
        return new AlgorithmResult(task.name(), task.category(), raceStart,
                raceStart.plusNanos(limitNs), limitNs, 0, 0, 0,
                false, true, null, null, "-");
    }

    // ------------------------------------------------------------- validacion

    private void validate(AlgorithmRaceRequest request) {
        if (request == null || request.arraySize() == null) {
            throw new InvalidRaceRequestException("El tamano del arreglo es obligatorio");
        }
        if (request.arraySize() < 1) {
            throw new InvalidRaceRequestException("El tamano del arreglo debe ser al menos 1");
        }
        if (request.target() == null) {
            throw new InvalidRaceRequestException("El numero buscado es obligatorio");
        }

        // Sin tope fijo: solo se rechaza lo que fisicamente no cabe en la memoria del servidor
        Runtime runtime = Runtime.getRuntime();
        long free = runtime.maxMemory() - (runtime.totalMemory() - runtime.freeMemory());
        long maxElements = (long) (free * 0.8) / ((long) ARRAYS_IN_MEMORY * Integer.BYTES);
        if (request.arraySize() > maxElements) {
            throw new InvalidRaceRequestException(
                    "El servidor no tiene memoria para ese tamano. Con la memoria actual "
                            + "el maximo es aproximadamente " + maxElements + " elementos");
        }
    }

    /** Una busqueda es correcta si coincide con la verdad (el numero existe o no). */
    private boolean searchIsCorrect(int[] array, int target, Integer index, boolean targetExists) {
        if (index == null) {
            return false;
        }
        if (index >= 0) {
            return targetExists && array[index] == target;
        }
        return !targetExists;
    }

    // ---------------------------------------------------------- datos y ranking

    /** Enteros aleatorios en [0, size): asi el numero buscado suele existir. */
    private int[] generateArray(int size) {
        Random random = new Random();
        int[] array = new int[size];
        for (int i = 0; i < size; i++) {
            array[i] = random.nextInt(size);
        }
        return array;
    }

    /** Duracion aproximada de la carrera: del primer inicio al ultimo fin. */
    private double totalRaceMs(List<AlgorithmResult> results) {
        LocalDateTime first = results.stream().map(AlgorithmResult::startTime)
                .min(Comparator.naturalOrder()).orElseThrow();
        LocalDateTime last = results.stream().map(AlgorithmResult::endTime)
                .max(Comparator.naturalOrder()).orElseThrow();
        return Duration.between(first, last).toNanos() / 1_000_000.0;
    }

    private AlgorithmRaceResponse buildResponse(int size, int target, List<AlgorithmResult> results) {
        List<RankingEntryDto> ranking = rank(results, null);
        List<RankingEntryDto> sortRanking = rank(results, Category.SORT);
        List<RankingEntryDto> searchRanking = rank(results, Category.SEARCH);

        return new AlgorithmRaceResponse(
                size, target,
                Runtime.getRuntime().availableProcessors(),
                timeLimitSeconds,
                totalRaceMs(results),
                results.stream().map(this::toDto).toList(),
                firstName(ranking), firstName(sortRanking), firstName(searchRanking),
                ranking, sortRanking, searchRanking);
    }

    /** Ordena por durationNanoseconds (menor a mayor). category null = todos. */
    private List<RankingEntryDto> rank(List<AlgorithmResult> results, Category category) {
        List<AlgorithmResult> ordered = results.stream()
                .filter(r -> r.success() && (category == null || r.category() == category))
                .sorted(Comparator.comparingLong(AlgorithmResult::durationNanoseconds))
                .toList();

        List<RankingEntryDto> ranking = new ArrayList<>();
        for (int i = 0; i < ordered.size(); i++) {
            AlgorithmResult r = ordered.get(i);
            ranking.add(new RankingEntryDto(i + 1, r.algorithm(), r.category().name(),
                    r.durationMilliseconds(), r.durationNanoseconds()));
        }
        return ranking;
    }

    private String firstName(List<RankingEntryDto> ranking) {
        return ranking.isEmpty() ? null : ranking.get(0).algorithm();
    }

    /**
     * Hora como instante UTC ("...Z"). El servidor guarda la hora local de su
     * JVM (en Docker es UTC); al enviarla con zona, Flutter la convierte a la
     * hora del equipo del usuario.
     */
    private String toInstant(LocalDateTime time) {
        return time.atZone(ZoneId.systemDefault()).toInstant().toString();
    }

    private AlgorithmResultDto toDto(AlgorithmResult r) {
        return new AlgorithmResultDto(r.algorithm(), r.category().name(),
                toInstant(r.startTime()), toInstant(r.endTime()),
                r.durationMilliseconds(), r.durationNanoseconds(),
                r.memoryBeforeBytes(), r.memoryDuringBytes(), r.memoryAfterBytes(),
                r.success(), r.timedOut(), r.found(), r.index(), r.threadName());
    }
}
