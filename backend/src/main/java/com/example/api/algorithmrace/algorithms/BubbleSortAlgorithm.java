package com.example.api.algorithmrace.algorithms;

/**
 * Bubble Sort (ordenamiento burbuja), implementado a mano.
 *
 * Recorre el arreglo comparando pares vecinos y los intercambia si estan
 * en desorden. En cada pasada el mayor "sube" al final. Complejidad O(n^2).
 */
public class BubbleSortAlgorithm {

    public void sort(int[] array) {
        int n = array.length;
        for (int pass = 0; pass < n - 1; pass++) {
            RaceCancelledException.checkInterrupted(); // solo para el tiempo límite
            boolean swapped = false;
            // Los ultimos "pass" elementos ya quedaron en su lugar
            for (int i = 0; i < n - 1 - pass; i++) {
                if (array[i] > array[i + 1]) {
                    int temp = array[i];
                    array[i] = array[i + 1];
                    array[i + 1] = temp;
                    swapped = true;
                }
            }
            // Sin intercambios en una pasada: el arreglo ya esta ordenado
            if (!swapped) {
                break;
            }
        }
    }
}
