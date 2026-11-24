package com.example.api.algorithmrace.algorithms;

/**
 * Insertion Sort (ordenamiento por insercion), implementado a mano.
 *
 * Mantiene una parte izquierda ya ordenada. Cada elemento nuevo se
 * "inserta" en su posicion correcta desplazando a los mayores. O(n^2).
 */
public class InsertionSortAlgorithm {

    public void sort(int[] array) {
        for (int i = 1; i < array.length; i++) {
            RaceCancelledException.checkInterrupted(); // solo para el tiempo límite
            int key = array[i];
            int j = i - 1;
            // Desplaza a la derecha los elementos mayores que "key"
            while (j >= 0 && array[j] > key) {
                array[j + 1] = array[j];
                j--;
            }
            array[j + 1] = key;
        }
    }
}
