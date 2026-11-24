package com.example.api.algorithmrace.algorithms;

/**
 * Quick Sort, implementado a mano (divide y venceras).
 *
 * 1. Elige un pivote (el elemento central).
 * 2. Particiona: menores a la izquierda, mayores a la derecha.
 * 3. Repite recursivamente en cada mitad.
 * Promedio O(n log n).
 */
public class QuickSortAlgorithm {

    public void sort(int[] array) {
        quickSort(array, 0, array.length - 1);
    }

    private void quickSort(int[] array, int low, int high) {
        if (low >= high) {
            return;
        }
        RaceCancelledException.checkInterrupted(); // solo para el tiempo límite
        int pivotIndex = partition(array, low, high);
        quickSort(array, low, pivotIndex - 1);
        quickSort(array, pivotIndex + 1, high);
    }

    /** Esquema de Lomuto: deja el pivote en su posicion final y la devuelve. */
    private int partition(int[] array, int low, int high) {
        // Pivote central: evita el peor caso en arreglos ya ordenados
        int middle = low + (high - low) / 2;
        swap(array, middle, high);
        int pivot = array[high];

        int boundary = low; // todo lo anterior a "boundary" es menor que el pivote
        for (int i = low; i < high; i++) {
            if (array[i] < pivot) {
                swap(array, i, boundary);
                boundary++;
            }
        }
        swap(array, boundary, high);
        return boundary;
    }

    private void swap(int[] array, int a, int b) {
        int temp = array[a];
        array[a] = array[b];
        array[b] = temp;
    }
}
